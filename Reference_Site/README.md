# GASNT Quick Reference

This folder contains a rebuilt static GASNT quick-reference dashboard.

Open `index.html` directly from disk. The runtime page uses `index.html`, `styles.css`, `data.js`, and `app.js`; no build tools, remote fonts, CDNs, package managers, or internet access are required.

Most editable dashboard content lives in `data.js`. The small `app.js` renderer turns that manifest into the tables, visual sections, and collapsible containers used by the page.

The page preserves the source dashboard structure: orientation image, top-level manuals, collapsible diagram/reference groups, the drawings matrix, cable lookup, test documents/tools, NI Max settings, and applicable procedures.

The referenced `DOC_LINKS`, `HTML_SUBCONTENT`, and `GASN2T_files` paths are intentionally preserved as recovered from the source page. Their existence was not checked on this machine.
