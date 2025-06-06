# # # cd backend
# # # uvicorn app:app --reload --port 8000
# # #
# # # cd frontend
# # # python -m http.server 8080
# # # http://localhost:8080/index.html
# # # CC(=O)Oc1ccccc1C(=O)O

import numpy as np
from collections import Counter
from sklearn.neural_network import MLPClassifier
from sklearn.metrics import classification_report, roc_auc_score

# Load data
train = np.load("drugbank_data/dti_dataset_train.npz", allow_pickle=True)
test = np.load("drugbank_data/dti_dataset_test.npz", allow_pickle=True)
Xd_train, Xp_train, y_train = train["X_drug"], train["X_prot"], train["y"]
Xd_test, Xp_test, y_test = test["X_drug"], test["X_prot"], test["y"]

# Build k-mer vocabulary
all_seqs = np.concatenate([Xp_train, Xp_test])
kmers = Counter()
for s in all_seqs:
    kmers.update(s[i:i+3] for i in range(len(s)-2))
kmer_vocab = [k for k,_ in kmers.most_common(500)]

# Encode proteins
def kmer_encode(seq):
    counts = Counter(seq[i:i+3] for i in range(len(seq)-2))
    return np.array([counts.get(k, 0) for k in kmer_vocab], dtype=float)

Xp_train_enc = np.vstack([kmer_encode(s) for s in Xp_train])
Xp_test_enc = np.vstack([kmer_encode(s) for s in Xp_test])

# Combine features
X_train = np.hstack([Xd_train, Xp_train_enc])
X_test = np.hstack([Xd_test, Xp_test_enc])

# Train model
clf = MLPClassifier(hidden_layer_sizes=(512, 256),
                   activation="relu", max_iter=50, random_state=42)
clf.fit(X_train, y_train)

# Evaluate
y_pred = clf.predict(X_test)
y_prob = clf.predict_proba(X_test)[:,1]
print(classification_report(y_test, y_pred))
print("ROC AUC:", roc_auc_score(y_test, y_prob))