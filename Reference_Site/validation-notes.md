# Validation Notes

Sources inspected:
- `_local/References/Reference_Page/Reference_Site_Rebuild_Prompt.md`
- `_local/References/Reference_Page/reference_page.html`
- `_local/References/Reference_Page/Source_Site_Images/01.jpg` through `13.jpg`

Runtime output:
- `index.html`
- `styles.css`
- `data.js`
- `app.js`
- `README.md`
- `validation-notes.md`

Major dashboard blocks rebuilt:
- GASNT title and large system overview image.
- Revision verification banner, Acronym Glossary entry in Top Level Guides and Manuals, and top-level manuals remain visible outside collapsible containers.
- Collapsible groups render Component Tree Diagrams, System Block Diagrams, System Interconnect Diagrams, Component Diagrams & Schematics, Cable Diagrams, and Misc Reference Documents.
- System block diagram, detail block diagram, and system interconnect thumbnail tables.
- Family tree / parts lists / component numbers visual section.
- Drawings and supporting documentation matrix reorganized into CSV-style System/Unit/reference columns, with merged System group cells and color-ready cell metadata in `data.js`.
- Cable lookup table with cable IDs, drawing links, and operational notes.
- Misc Reference Documents uses one combined table for test documents/tools, Black Side NI Max instrument settings, and applicable procedures/findings/FNs.

Required spot checks:
- PASS: MPG row -> `Interconnect` link -> `SDA2080872`.
- PASS: MPG row -> `Elec Schematic` link -> `SDA2079676`.
- PASS: PDU row -> `Interconnect` link -> `SDA420722`.
- PASS: KOV-81/ACCG/KGV-136B/CTIA/ECU -> Design Docs -> `CSG FPGA ICD`, `CSGRM FPGA DD`, `ACCG DESIGN MEMO`, `FDX FPGA ICD`, `MAF FPGA ICD`.
- PASS: ACU block is separate from the MEC block, matching the provided CSV layout.
- PASS: ACU row -> `Interconnect` link -> `SDA2463423`.
- PASS: ACU row -> `Elec Schematic` link -> `SDA2463504`.
- PASS: ACU `- Cables` row -> `Cable Design` link -> `A4249379`.
- PASS: Cable lookup -> `W19/W21/W22/W43/W46/W51/W52/W53/W54/W55` -> `0N836190` -> copper KDS/KOV-81/KY-100/KIV-7/MPG/DLP note.
- PASS: Test documents/tools section keeps thumbnail rows and compact text-link rows.

Additional spot checks:
- PASS: DLP -> Interconnect -> `SDA2463191`, Schematic -> `SDA2905470`, Mechanical -> `PWA A2905470` and `A2463191`.
- PASS: KDS -> Schematic -> `0N836174`, Mechanical -> `CCA 0N836177`, Other -> `Parts List PL0N836177`.
- PASS: FIA -> Schematic -> `SDA2900065`, Mechanical -> `FIA Assemblies A2643758` and `PWA_PWA2900065`, Design Docs -> `FIA FPGA Design`, Other -> FIA detail/GPS/block/fiber links.
- PASS: System interconnect thumbnail table preserves description-to-image rows for Total GASNT, MEC, MEC side panel, ACU, antenna, ESS, SATCOM, and test rack interconnects.
- PASS: Family tree / parts lists section preserves two large linked visual previews plus TOP Parts List and System Indentured BOM links.
- PASS: Applicable procedures preserve `FNGASNT-017` and `Cold Boot Problem`.

Malformed or uncertain recovered content:
- The reconstructed HTML contains Word/VML debris, broken tags, and malformed table rows. These were cleaned from visible labels while preserving source link targets and table placement.
- The ACU block diagram image was inside damaged conditional markup; `GASN2T_files/image016.jpg` was retained as the visible thumbnail source.
- The MDU row was malformed in source HTML. No MDU interconnect link was recovered, so that reference cell is left blank; the recovered source links for `SDA2905470`, `PWA A2905470`, `A2463194`, and `Parts List PLA2463194` were preserved.
- The cable table contains malformed rows around `A4110763`, `0N836277`, `D3503802`, and `D3570041`. The visible cable ID groups, drawing links, and notes were preserved using source links and screenshot table shape.
- The source includes duplicate or malformed alternate cable targets for `A4110763` and `0N836277`; distinct recovered targets are retained in the cable table.
- The TEST MATRIX row has a document link but no recoverable `img src`/`v:imagedata src` in the source fragment, even though the screenshot shows a visual preview. The row and `TEST MATRIX` link were preserved; no image reference was invented.
- The Fiber Pinouts for Test Rack row is visible in the screenshot with an `EXCEL` label, but no distinct recoverable `href` was found in the source fragment. The row and label were retained without inventing a target.
- Link inventory check found one source `href` not used in the runtime page: the VML-only family-tree shape target `DOC_LINKS/global%20breakdown .xlsx` with an extra space before `.xlsx`. The visible outer anchor target `DOC_LINKS/global%20breakdown.xlsx` was preserved.

Omitted content:
- Server Location and Edits/Corrections/Suggestions were removed during cleanup as outdated administrative content.
- GASNT Help Desk Contact Info and GASNT Contacts were removed during cleanup as outdated support/contact content for a system no longer in production.
- The old `ALL DOCUMENTS FOR REFERENCE ONLY` banner and Windchill/PDM access links were removed as outdated; they were replaced with the top banner `VERIFY REVISION OF ALL DOCUMENTS PRIOR TO USE`.
- No operational dashboard section was intentionally omitted.
- Word-generated document metadata/resource links such as `GASN2T_files/filelist.xml`, `editdata.mso`, data store XML, theme data, color scheme mapping, and VML-only duplicate shape links were not added as visible runtime dashboard entries.

Path handling:
- Original `href` and `src` values were preserved where recovered.
- Referenced local document/image folders were not verified or copied; the target air-gapped workstation is expected to provide those paths.
- Runtime content is now driven by `data.js` and rendered by a small vanilla `app.js`; no search, filtering, counts, diagnostics panel, CDN, package manager, or remote runtime dependency was added.
