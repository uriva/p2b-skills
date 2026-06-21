---
name: p2b-document-pipeline
description: Best practices for building high-precision, cost-optimized document extraction and parsing pipelines. Covers OCR vs. direct PDF text extraction, handling image documents (JPG/PNG), model selection (Gemini vs. Claude), and structured data mapping.
---

# p2b-document-pipeline

Guidelines and best practices for building robust document ingestion, parsing, and data extraction pipelines for CRMs, databases, and automated workflows.

## Guidelines & Architecture

### 1. Model Selection & Precision
- **Gemini is highly recommended for multi-page documents:** For multi-page documents (e.g., 7-8 page insurance policy documents), latest Gemini models deal with extremely large contexts and native structure extraction exceptionally well and at a fraction of the cost.
- **Claude limitations:** While models like the latest Claude are excellent at reasoning, they can occasionally hallucinate, drift, or make mistakes when scanning raw multi-page document images directly. 

### 2. PDF Processing: Direct Text Extraction vs. OCR
- **Identify Native PDFs First:** Always check if the input document is a native PDF (with selectable text) rather than a scanned image PDF.
- **Never run OCR on Native PDFs:** For native PDFs, do **not** use OCR or vision processing. Instead, convert the PDF directly to plain text programmatically (e.g., using simple text extraction libraries like `pdf-parse` in Node or standard deno PDF parsing libraries). Direct text extraction is:
  - **100% Accurate:** Zero OCR recognition errors.
  - **Vastly Cheaper:** Avoids image processing and vision token fees.
  - **Significantly Faster:** Takes milliseconds instead of seconds.

### 3. Image (JPG/PNG/Scanned PDF) Processing Strategy
- **Avoid raw image multimodal ingestion for complex layout analysis:** Sending raw multi-page high-resolution images (JPG, PNG, or scanned PDFs) directly into multimodal LLM inputs is expensive, high-latency, and prone to hallucination/skipping.
- **Use OCR-First Pipelines:** For scanned documents and images:
  1. Run a dedicated high-precision OCR first (such as **Google Cloud Vision OCR**).
  2. Extract the full document as plain text.
  3. Pass the clean text to the LLM (e.g., Gemini or Claude) along with your desired target schema to extract the specific fields.
  4. This decouples visual text recognition from semantic data extraction, providing much higher precision at a lower cost.

### 4. Handling Provider-Specific Structure Variance
- **Acknowledge Fixed-but-Varied Layouts:** In industries like insurance, each provider or company usually has its own fixed document structure, but the structure varies wildly between different providers.
- **Structured Data Mapping:** Leverage structured JSON schemas (`responseSchema` or structured outputs) in the LLM call to map extracted text directly into a rigid JSON target format.
- **Schema-Based Normalization:** Let the LLM map the semantic meaning (e.g., "Premium", "Policy Start Date") into a standardized format regardless of which provider's layout it is parsing.
