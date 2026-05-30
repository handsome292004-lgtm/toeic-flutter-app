import json
import pandas as pd

INPUT_XLSX = "tu_vung.xlsx"
OUTPUT_JSON = "assets/vocabulary.json"
SHEET_NAME = "For App"  # đổi thành None nếu muốn lấy sheet đầu tiên

sheet = SHEET_NAME
if sheet is None:
    sheet = pd.ExcelFile(INPUT_XLSX).sheet_names[0]

df = pd.read_excel(INPUT_XLSX, sheet_name=sheet)
if "Topic" not in df.columns:
    df["Topic"] = "General"

items = []
seen = set()
for _, row in df.iterrows():
    english = str(row.get("English", "")).strip()
    vietnamese = str(row.get("Vietnamese", "")).strip()
    topic = str(row.get("Topic", "General")).strip() or "General"
    if not english or not vietnamese or english.lower() == "nan" or vietnamese.lower() == "nan":
        continue
    key = (topic.lower(), english.lower(), vietnamese.lower())
    if key in seen:
        continue
    seen.add(key)
    items.append({
        "id": len(items) + 1,
        "topic": topic,
        "english": english,
        "vietnamese": vietnamese,
    })

with open(OUTPUT_JSON, "w", encoding="utf-8") as f:
    json.dump(items, f, ensure_ascii=False, indent=2)

print(f"Đã tạo {OUTPUT_JSON} với {len(items)} từ.")
