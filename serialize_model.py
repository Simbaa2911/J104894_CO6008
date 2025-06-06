import json
import pickle
from Bio import SeqIO
from train_model import clf, kmer_vocab  # Run train_model.py first

if __name__ == "__main__":
    # 1) Save the trained model + kmer_vocab
    with open("drugbank_data/model.pkl", "wb") as f:
        pickle.dump((clf, kmer_vocab), f)

    # 2) Re‐extract UniProt IDs from the raw FASTA so they match exactly what app.py will load
    #    The FASTA header lines look like:  >sp|P12345|PROTEIN_HUMAN ...
    #    We want the second “|”-delimited field (e.g. “P12345”).
    prot_seqs = {}
    for rec in SeqIO.parse("drugbank_data/protein.fasta", "fasta"):
        parts = rec.id.split("|")
        if len(parts) >= 2:
            uni = parts[1]
            prot_seqs[uni] = str(rec.seq)

    # 3) Write out targets.json = { "targets": [ <all UniProt IDs> ] }
    target_list = list(prot_seqs.keys())
    with open("drugbank_data/targets.json", "w") as f:
        json.dump({"targets": target_list}, f)
