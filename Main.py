import pandas as pd
import numpy as np
import random
import pickle
from rdkit import Chem
from rdkit.Chem import AllChem
from Bio import SeqIO
from sklearn.model_selection import train_test_split


def load_drugs_from_sdf(sdf_path):
    suppl = Chem.SDMolSupplier(sdf_path)
    valid = {}
    for mol in suppl:
        if mol is None: continue
        try:
            Chem.SanitizeMol(mol)
        except:
            continue
        db_id = mol.GetProp('DRUGBANK_ID') if mol.HasProp('DRUGBANK_ID') else mol.GetProp('_Name')
        valid[db_id] = mol
    return valid


def generate_fingerprints(drug_mol_dict, radius=2, nBits=2048):
    fps = {}
    bit_explanations = {}
    for db_id, mol in drug_mol_dict.items():
        bitInfo = {}
        try:
            fp = AllChem.GetMorganFingerprintAsBitVect(mol, radius, nBits=nBits, bitInfo=bitInfo)
        except Exception as e:
            print(f"Skipping {db_id} due to error: {str(e)}")
            continue

        arr = np.zeros((nBits,), dtype=int)
        AllChem.DataStructs.ConvertToNumpyArray(fp, arr)
        fps[db_id] = arr

        for bit, occurrences in bitInfo.items():
            if bit in bit_explanations: continue
            if not occurrences: continue
            try:
                atom_idx, rad = occurrences[0]
                env = Chem.FindAtomEnvironmentOfRadiusN(mol, rad, atom_idx)
                submol = Chem.PathToSubmol(mol, env)
                smarts = Chem.MolToSmarts(submol)
                bit_explanations[bit] = smarts
            except Exception as e:
                print(f"Couldn't process bit {bit} for {db_id}: {str(e)}")
                continue

    with open("drugbank_data/bit_explanations.pkl", "wb") as f:
        pickle.dump(bit_explanations, f)

    return fps


def load_fasta_sequences(fasta_file):
    seqs = {}
    for rec in SeqIO.parse(fasta_file, "fasta"):
        if "|" in rec.id:
            _, uni = rec.id.split("|")
            seqs[uni] = str(rec.seq)
    return seqs


def load_drug_to_uniprot(csv_file):
    df = pd.read_csv(csv_file, low_memory=False)
    return df.groupby("DrugBank ID")["UniProt ID"].apply(list).to_dict()


def build_positive_pairs(drug_fps, prot_seqs, drug2unis):
    positives = []
    for db_id, unis in drug2unis.items():
        if (fp := drug_fps.get(db_id)) is None: continue
        for uni in unis:
            if (seq := prot_seqs.get(uni)) is None: continue
            positives.append((fp, seq, 1))
    return positives


def build_negative_pairs(drug_fps, prot_seqs, positives, ratio=1):
    pos_set = set((db, uni) for db, unis in drug2unis.items() for uni in unis)
    drug_ids = list(drug_fps.keys())
    prot_ids = list(prot_seqs.keys())
    negatives = []
    attempts = 0
    while len(negatives) < len(positives) * ratio and attempts < 1e5:
        db = random.choice(drug_ids)
        uni = random.choice(prot_ids)
        if (db, uni) in pos_set: continue
        negatives.append((drug_fps[db], prot_seqs[uni], 0))
        attempts += 1
    return negatives


def save_dataset(positives, negatives, out_path_prefix):
    data = positives + negatives
    X_drug = np.stack([d[0] for d in data])
    X_prot = np.array([d[1] for d in data], dtype=object)
    y = np.array([d[2] for d in data])

    Xd_train, Xd_test, Xp_train, Xp_test, y_train, y_test = train_test_split(
        X_drug, X_prot, y, test_size=0.2, stratify=y, random_state=42
    )

    np.savez_compressed(f"{out_path_prefix}_train.npz", X_drug=Xd_train, X_prot=Xp_train, y=y_train)
    np.savez_compressed(f"{out_path_prefix}_test.npz", X_drug=Xd_test, X_prot=Xp_test, y=y_test)


if __name__ == "__main__":
    drug_mols = load_drugs_from_sdf("drugbank_data/structures.sdf")
    drug_fps = generate_fingerprints(drug_mols)
    prot_seqs = load_fasta_sequences("drugbank_data/protein.fasta")
    drug2unis = load_drug_to_uniprot("drugbank_data/uniprot_links.csv")

    positives = build_positive_pairs(drug_fps, prot_seqs, drug2unis)
    negatives = build_negative_pairs(drug_fps, prot_seqs, positives)

    save_dataset(positives, negatives, "drugbank_data/dti_dataset")