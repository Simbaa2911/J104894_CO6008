import json
import pickle
import numpy as np
from collections import Counter
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from rdkit import Chem
from rdkit.Chem import AllChem, Draw
from rdkit.DataStructs import ConvertToNumpyArray
from rdkit.Chem.Draw import rdMolDraw2D
from Bio import SeqIO
import shap

app = FastAPI(title="DTI Predictor API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ————— Load precomputed resources ——————————————————————————————————————————————————

# 1) fingerprint bit → SMARTS explanations
with open("../drugbank_data/bit_explanations.pkl", "rb") as f:
    BIT_EXPLANATIONS = pickle.load(f)

# 2) trained model + k-mer vocabulary
with open("../drugbank_data/model.pkl", "rb") as f:
    clf, kmer_vocab = pickle.load(f)

# 3) list of valid UniProt IDs (written by serialize_model.py)
with open("../drugbank_data/targets.json") as f:
    TARGET_DATA = json.load(f)
    TARGETS = TARGET_DATA["targets"]  # e.g. ["P12345", "Q8N158", …]

# 4) load raw FASTA so that:
#    - prot_seqs[uni] = sequence
#    - target_info[uni] = human‐readable description from FASTA header
prot_seqs = {}
target_info = {}

for rec in SeqIO.parse("../drugbank_data/protein.fasta", "fasta"):
    parts = rec.id.split("|")
    if len(parts) >= 2:
        uni = parts[1]
        prot_seqs[uni] = str(rec.seq)

        desc = rec.description
        desc_parts = desc.split(" ", 1)
        if len(desc_parts) == 2:
            human_name = desc_parts[1]
        else:
            human_name = desc_parts[0]
        target_info[uni] = human_name

for uni in TARGETS:
    if uni not in target_info:
        target_info[uni] = "Unknown description"

# ————— Constants ——————————————————————————————————————————————————————————————

N_FP_BITS = 2048        # length of Morgan fingerprint
LEN_KMER = len(kmer_vocab)
NUM_FEATURES = N_FP_BITS + LEN_KMER  # total features in combined vector

# ————— Mappings for human-friendly labels ————————————————————————————————————————————

AA_3LETTER = {
    "A": "Ala", "R": "Arg", "N": "Asn", "D": "Asp",
    "C": "Cys", "E": "Glu", "Q": "Gln", "G": "Gly",
    "H": "His", "I": "Ile", "L": "Leu", "K": "Lys",
    "M": "Met", "F": "Phe", "P": "Pro", "S": "Ser",
    "T": "Thr", "W": "Trp", "Y": "Tyr", "V": "Val"
}

NAMED_FUNCS = {
    "alcohol": "[OX2H]",
    "primary amine": "[NX3;H2]",
    "secondary amine": "[NX3;H1]",
    "tertiary amine": "[NX3;!H0]",
    "carbonyl (ketone)": "[CX3](=[OX1])[#6]",
    "aldehyde": "[CX3H1](=O)[#6]",
    "carboxylic acid": "[CX3](=O)[OX2H1]",
    "ester": "[CX3](=O)[OX2][#6]",
    "amide": "[NX3][CX3](=[OX1])[#6]",
    "aromatic ring (benzene)": "c1ccccc1",
    "heterocycle (pyridine)": "c1ccncc1",
    "five-membered heterocycle (thiophene)": "c1ccsc1",
    "thiol": "[SX2H]",
    "ether": "[OD2]([#6])[#6]",
    "thioether": "[SD2]([#6])[#6]",
    "fluoro": "[F]",
    "chloro": "[Cl]",
    "bromo": "[Br]",
    "iodo": "[I]",
    "nitro": "[NX3](=O)(=O)[#6]",
    "phosphate": "[PX4](=O)(O)(O)[O]",
    "alkyne": "[C]#[C]",
    "alkene": "[C]=[C]",
}

# ————— Helper functions ——————————————————————————————————————————————————————————

def fingerprint(smiles: str) -> np.ndarray:
    mol = Chem.MolFromSmiles(smiles)
    if mol is None:
        raise ValueError("Invalid SMILES string")
    fp_obj = AllChem.GetMorganFingerprintAsBitVect(mol, radius=2, nBits=N_FP_BITS)
    arr = np.zeros((N_FP_BITS,), dtype=int)
    ConvertToNumpyArray(fp_obj, arr)
    return arr

def kmer_encode_seq(seq: str) -> np.ndarray:
    counts = Counter(seq[i : i + 3] for i in range(len(seq) - 2))
    return np.array([counts.get(k, 0) for k in kmer_vocab], dtype=float)

def human_prot_3mer(trimer: str) -> str:
    return "-".join(AA_3LETTER.get(x, x) for x in trimer)

def generic_smarts_description(smarts: str) -> str:
    try:
        submol = Chem.MolFromSmarts(smarts)
        if not submol:
            return smarts
        atom_symbols = [atom.GetSymbol() for atom in submol.GetAtoms()]
        atom_counts = Counter(atom_symbols)
        bond_kinds = []
        for bond in submol.GetBonds():
            bt = bond.GetBondType()
            if bt == Chem.rdchem.BondType.SINGLE:
                bond_kinds.append("single")
            elif bt == Chem.rdchem.BondType.DOUBLE:
                bond_kinds.append("double")
            elif bt == Chem.rdchem.BondType.TRIPLE:
                bond_kinds.append("triple")
            elif bt == Chem.rdchem.BondType.AROMATIC:
                bond_kinds.append("aromatic")
        parts = []
        for el, cnt in atom_counts.items():
            parts.append(f"{cnt}×{el}")
        atom_part = " ".join(parts)
        bond_unique = sorted(set(bond_kinds))
        bond_part = " & ".join(bond_unique) + " bonds"
        return f"{atom_part} ({bond_part})"
    except Exception:
        return smarts

def describe_smarts_and_svg(smarts: str):
    human_label = smarts
    svg = ""
    try:
        submol = Chem.MolFromSmarts(smarts)
        if submol:
            for name, pattern in NAMED_FUNCS.items():
                patt = Chem.MolFromSmarts(pattern)
                if patt and submol.HasSubstructMatch(patt):
                    human_label = name + "-like fragment"
                    break
            else:
                human_label = generic_smarts_description(smarts)
            drawer = Draw.MolDraw2DSVG(150, 150)
            opts = drawer.drawOptions()
            opts.padding = 0.15
            drawer.DrawMolecule(submol)
            drawer.FinishDrawing()
            svg = drawer.GetDrawingText()
    except Exception:
        human_label = generic_smarts_description(smarts)
        svg = ""
    return human_label, svg

def highlight_substructure_on_query(smarts: str, query_smiles: str) -> str:
    try:
        query_mol = Chem.MolFromSmiles(query_smiles)
        patt = Chem.MolFromSmarts(smarts)
        if query_mol is None or patt is None:
            return ""
        match_indices = list(query_mol.GetSubstructMatch(patt))
        if not match_indices:
            return ""
        atom_highlight = {idx: (1.0, 0.0, 0.0) for idx in match_indices}
        bond_highlight = {}
        for bond in query_mol.GetBonds():
            a1, a2 = bond.GetBeginAtomIdx(), bond.GetEndAtomIdx()
            if a1 in match_indices and a2 in match_indices:
                bond_highlight[bond.GetIdx()] = (1.0, 0.0, 0.0)
        drawer = rdMolDraw2D.MolDraw2DSVG(300, 300)
        opts = drawer.drawOptions()
        opts.padding = 0.1
        rdMolDraw2D.PrepareAndDrawMolecule(
            drawer,
            query_mol,
            highlightAtoms=match_indices,
            highlightAtomColors=atom_highlight,
            highlightBonds=list(bond_highlight.keys()),
            highlightBondColors=bond_highlight,
        )
        drawer.FinishDrawing()
        return drawer.GetDrawingText()
    except Exception:
        return ""

# ————— Build SHAP background ——————————————————————————————————————————————————————————

train_data = np.load("../drugbank_data/dti_dataset_train.npz", allow_pickle=True)
bg_drug = train_data["X_drug"][:50]
bg_prot = np.vstack([kmer_encode_seq(prot_seqs[uid]) for uid in TARGETS[:50]])
background = np.hstack([bg_drug, bg_prot])

explainer = shap.KernelExplainer(clf.predict_proba, background)

# ————— In-memory cache for SHAP explanations ——————————————————————————————————————————————
# Keyed by (smiles, target) → { "probability": float, "explanation": [ … ] }
EXPLANATION_CACHE = {}

# ————— FastAPI schemas ——————————————————————————————————————————————————————————
class Query(BaseModel):
    smiles: str
    target: str

# ————— Endpoints ——————————————————————————————————————————————————————————————

@app.get("/targets")
def get_targets():
    return {"targets": TARGETS}

@app.get("/target-info")
def get_target_info():
    info_list = [{"id": uid, "name": target_info[uid]} for uid in sorted(TARGETS)]
    return {"targets": info_list}

@app.post("/predict")
def predict(query: Query):
    """
    Input:  { "smiles": "...", "target": "Q02338" }
    Output: {
      "probability": 0.72,
      "explanation": [ … ]
    }
    """
    try:
        # 1) Normalize key for caching
        key = (query.smiles.strip(), query.target.strip())

        # 2) If we've already computed this pair, return cached result
        if key in EXPLANATION_CACHE:
            return EXPLANATION_CACHE[key]

        # 3) Compute fingerprint + protein vector
        fp_vec = fingerprint(query.smiles)
        if query.target not in prot_seqs:
            raise KeyError(f"Unknown target ID: {query.target}")
        prot_vec = kmer_encode_seq(prot_seqs[query.target])

        x = np.hstack([fp_vec, prot_vec]).reshape(1, -1)

        # 4) Predict probability
        prob = float(clf.predict_proba(x)[0][1])

        # 5) Compute SHAP values
        shap_out = explainer.shap_values(x, nsamples=100, random_state=42)
        arr = np.array(shap_out)

        # Unwrap into 1D shap_vals
        if arr.ndim == 1 and arr.shape[0] == 2 * NUM_FEATURES:
            shap_vals = arr.reshape(2, NUM_FEATURES)[1]
        elif arr.ndim == 2 and arr.shape[0] == 2 and arr.shape[1] == NUM_FEATURES:
            shap_vals = arr[1]
        elif arr.ndim == 2 and arr.shape[0] == 1 and arr.shape[1] == NUM_FEATURES:
            shap_vals = arr[0]
        elif arr.ndim == 1 and arr.shape[0] == NUM_FEATURES:
            shap_vals = arr
        elif arr.ndim == 3 and arr.shape == (1, NUM_FEATURES, 2):
            shap_vals = arr[0, :, 1]
        else:
            raise Exception(
                f"Unexpected SHAP output shape: {arr.shape} "
                f"(expected (2, {NUM_FEATURES}), (1, {NUM_FEATURES}), "
                f"({NUM_FEATURES},), or (1, {NUM_FEATURES}, 2), or (2*{NUM_FEATURES},))"
            )

        # 6) Pick top-10 features
        top_idx = np.argsort(np.abs(shap_vals))[::-1][:10]
        explanation = []

        for i in top_idx:
            if i < N_FP_BITS:
                raw_smarts = BIT_EXPLANATIONS.get(i, None)
                if raw_smarts:
                    label, frag_svg = describe_smarts_and_svg(raw_smarts)
                    full_svg = highlight_substructure_on_query(raw_smarts, query.smiles)
                    explanation.append({
                        "feature_type": "chemical",
                        "smarts": raw_smarts,
                        "label": label,
                        "svg": frag_svg,
                        "svg_full": full_svg,
                        "impact": float(shap_vals[i])
                    })
                else:
                    explanation.append({
                        "feature_type": "chemical",
                        "smarts": None,
                        "label": f"FP_bit_{i}",
                        "svg": "",
                        "svg_full": "",
                        "impact": float(shap_vals[i])
                    })
            else:
                trimer = kmer_vocab[i - N_FP_BITS]
                human_label = human_prot_3mer(trimer)
                explanation.append({
                    "feature_type": "protein",
                    "trimer": trimer,
                    "label": human_label,
                    "impact": float(shap_vals[i])
                })

        response = {"probability": prob, "explanation": explanation}

        # 7) Cache and return
        EXPLANATION_CACHE[key] = response
        return response

    except KeyError as ke:
        raise HTTPException(status_code=400, detail=str(ke))
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
