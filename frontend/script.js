// const API = "http://localhost:8000";
const API = "";

// 1) Load full (ID → Name) list into a scrollable table on page load
async function loadTargetList() {
  try {
    const res = await fetch(`${API}/target-info`);
    if (!res.ok) {
      const errBody = await res.json();
      throw new Error(errBody.detail || "Failed to load target info");
    }
    const data = await res.json();
    const tbody = document.getElementById("targetListBody");

    data.targets.forEach((item) => {
      const row = document.createElement("tr");
      row.dataset.uni = item.id;  // store UniProt ID

      // First cell: ID
      const cellId = document.createElement("td");
      cellId.textContent = item.id;
      // Second cell: description
      const cellName = document.createElement("td");
      cellName.textContent = item.name;

      row.appendChild(cellId);
      row.appendChild(cellName);

      // When a user clicks this row → mark selected & set hidden input
      row.addEventListener("click", () => {
        // Un-highlight any previously selected row
        const prev = tbody.querySelector("tr.selected");
        if (prev) prev.classList.remove("selected");
        // Highlight this one
        row.classList.add("selected");
        // Store the ID in hidden input
        document.getElementById("targetInput").value = item.id;
      });

      tbody.appendChild(row);
    });
  } catch (err) {
    console.error("Error loading target info:", err);
    alert("Failed to load targets. See console for details.");
  }
}

// 2) Get SMILES from JSME when “Get SMILES” button is clicked
document.getElementById("getSmiles").onclick = () => {
  if (!window.jsmeApplet) {
    alert("Molecule editor not yet ready. Please wait.");
    return;
  }
  try {
    const smiles = jsmeApplet.smiles();
    document.getElementById("smilesOut").textContent = smiles;
  } catch (err) {
    console.error("Error getting SMILES:", err);
    alert("Could not retrieve SMILES. Draw a molecule first.");
  }
};

// 3) When “Predict” button is clicked
document.getElementById("predictBtn").onclick = async () => {
  if (!window.jsmeApplet) {
    alert("Molecule editor not ready.");
    return;
  }
  const smiles = jsmeApplet.smiles();
  const target = document.getElementById("targetInput").value;
  if (!smiles) {
    alert("Please draw a molecule.");
    return;
  }
  if (!target) {
    alert("Please click one target from the list above before pressing Predict.");
    return;
  }

  let res, data;
  try {
    res = await fetch(`${API}/predict`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ smiles, target }),
    });
    data = await res.json();
  } catch (err) {
    console.error("Network error:", err);
    alert("Network error during prediction.");
    return;
  }

  if (!res.ok) {
    console.error("Server error:", data.detail || data);
    alert("Prediction failed: " + (data.detail || "Unknown error"));
    return;
  }

  // Clear previous results
  const resultContainer = document.getElementById("result");
  resultContainer.innerHTML = "";

  // 3a) Show probability
  const pElem = document.createElement("div");
  pElem.innerHTML = `<strong>Probability:</strong> ${(data.probability * 100).toFixed(1)}%`;
  resultContainer.appendChild(pElem);

  // 3b) Heading for top influencing features
  const h3 = document.createElement("div");
  h3.innerHTML = `<strong>Top Influencing Features:</strong>`;
  h3.style.marginTop = "1em";
  resultContainer.appendChild(h3);

  // Collect positive/negative features here
  const positiveFeatures = [];
  const negativeFeatures = [];

  // 3c) For each explanation entry:
  data.explanation.forEach((e) => {
    if (e.feature_type === "protein") {
      const div = document.createElement("div");
      div.style.marginTop = "0.5em";
      const direction = e.impact > 0 ? "Increases" : "Decreases";
      div.textContent = `🧬 ${direction} (${Math.abs(e.impact).toFixed(3)}) – ${e.label}`;
      resultContainer.appendChild(div);

      // Collect text for summary
      if (e.impact > 0) {
        positiveFeatures.push(e.label);
      } else {
        negativeFeatures.push(e.label);
      }

    } else if (e.feature_type === "chemical") {
      const wrapper = document.createElement("div");
      wrapper.style.marginTop = "0.5em";

      // 3c-i) Fragment-only image (150×150)
      if (e.svg && e.svg.trim().length > 0) {
        const fragDiv = document.createElement("div");
        fragDiv.className = "fragment-svg";
        fragDiv.innerHTML = e.svg;
        wrapper.appendChild(fragDiv);
      }

      // 3c-ii) Generic label text
      const divText = document.createElement("div");
      const direction = e.impact > 0 ? "Increases" : "Decreases";
      divText.textContent = `⚗️ ${direction} (${Math.abs(e.impact).toFixed(3)}) – ${e.label}`;
      divText.style.marginTop = "0.25em";
      wrapper.appendChild(divText);

      // 3c-iii) Full-molecule highlight (300×300)
      if (e.svg_full && e.svg_full.trim().length > 0) {
        const fullDiv = document.createElement("div");
        fullDiv.className = "fragment-svg-full";
        fullDiv.innerHTML = e.svg_full;
        wrapper.appendChild(fullDiv);
      }

      resultContainer.appendChild(wrapper);

      // Collect text for summary
      if (e.impact > 0) {
        positiveFeatures.push(e.label);
      } else {
        negativeFeatures.push(e.label);
      }
    }
  });

  // 4) Paragraph:
  const summaryPara = document.createElement("p");
  summaryPara.style.marginTop = "1.5em";
  summaryPara.style.fontStyle = "italic";

  // Sentence 1: interaction vs. non-interaction
  const probNum = (data.probability * 100).toFixed(1);
  let sentence1 = "";
  if (data.probability >= 0.5) {
    sentence1 = `This molecule is predicted to interact with the chosen target (probability: ${probNum}%). `;
  } else {
    sentence1 = `This molecule is predicted not to interact with the chosen target (probability: ${probNum}%). `;
  }

  // Sentence 2: positive features (up to 3)
  let sentence2 = "";
  if (positiveFeatures.length > 0) {
    const topPos = positiveFeatures.slice(0, 3);
    if (topPos.length === 1) {
      sentence2 = `Notably, the feature “${topPos[0]}” contributes positively toward interaction. `;
    } else {
      sentence2 = `Notably, the features “${topPos.join('”, “')}” all contribute positively toward interaction. `;
    }
  }

  // Sentence 3: negative features (up to 3)
  let sentence3 = "";
  if (negativeFeatures.length > 0) {
    const topNeg = negativeFeatures.slice(0, 3);
    if (topNeg.length === 1) {
      sentence3 = `Conversely, the feature “${topNeg[0]}” contributes negatively toward interaction.`;
    } else {
      sentence3 = `Conversely, the features “${topNeg.join('”, “')}” contribute negatively toward interaction.`;
    }
  }

  summaryPara.textContent = sentence1 + sentence2 + sentence3;
  resultContainer.appendChild(summaryPara);
};

// Initialize on page load
document.addEventListener("DOMContentLoaded", () => {
  loadTargetList();
});
