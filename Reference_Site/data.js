const H = {
  acronyms: "HTML_SUBCONTENT/ACRONYMS.htm",
  toManual: "DOC_LINKS/GASNT%20TO%2031R2-2FRC192-1%20WPs%20Change%201%20(20221210).pdf",
  ssdd: "DOC_LINKS/Global_ASNT_SSDD%20MIR%20BOOKMARKED.pdf",
  troubleGuideDoc: "DOC_LINKS/GASN1%20Troubleshooting%20Guide_Rev%20-%20Locked.pdf",
  topPartsVisual: "DOC_LINKS/GASNT%20FIXED%20SYSTEM%20PARTS%20LIST%20p1a4274708-1_d_all_FOUO.pdf",
  topPartsMatrix: "DOC_LINKS/GASNT%20FIXED%20SYSTEM%20PARTS%20LIST%20pla4274708-1_d_all_FOUO.pdf",
  systemBom: "DOC_LINKS/System%20Indentured%20BOM%20V003.xlsx",
  acuBlock: "DOC_LINKS/ACU_Block_Diagram_Rev-9D%20NOT%20PDM.pdf",
  acuInterconnect: "DOC_LINKS/ACU%20INTERCONNECT%20DIAGRAM%20SDA2463423_e_all.pdf",
  acuCables: "DOC_LINKS/ACU%20CABLES%20a4249379_u_all.pdf",
  mduSchematic: "DOC_LINKS/DLP%20MDU%20SCHEMATIC%20DIAGRAM%20sda2905470_e_all%20(1).pdf",
  mduPwa: "DOC_LINKS/DLP%20MDU%20BACKPLANE%20PWA%20a2905470_j_all.pdf",
  essTest: "DOC_LINKS/ESS%20SYSTEM%20TEST%20INTERCONNECT%20sda7438303_a_all.pdf",
  testRackOld: "DOC_LINKS/TEST%20RACK%20INTERCONNECT%20sdc1855698_-_all.pdf",
  testRackNew: "DOC_LINKS/TEST%20RACK%20INTERCONNECT%20sdc1855698__all.pdf",
  serverMech: "DOC_LINKS/SERVER%20ASSEMBLY%20MECHANICAL%20a5256786_d_all.pdf",
  serverParts: "DOC_LINKS/SERVER%20PARTS%20LIST%20pla5256786_2_a_all.pdf",
  serverSpec: "DOC_LINKS/SERVER%20COMPUTER%20a2643736_d_all.pdf",
  dlpBackplane: "DOC_LINKS/DLP%20BACKPLANE%20PARTS%20LIST%20pla2905470-1_k_all.pdf"
};

const L = (label, href) => ({ label, href });
const P = text => ({ p: text });
const I = (href, src, width, height, alt, wide) => ({ href, src, width, height, alt, wide });
const C = (value, color = "") => ({ value, color });
const R = (...cells) => cells.map(cell => C(cell));

window.GASNT_DATA = {
  banner: "VERIFY REVISION OF ALL DOCUMENTS PRIOR TO USE",
  title: "GASNT",
  subtitle: "Global Aircrew Strategic Network Terminal",
  overview: {
    src: "GASN2T_files/image002.jpg",
    width: 960,
    height: 698,
    alt: "GASNT system overview diagram"
  },
  footer: "Author: Brandon M. Heath - 1130538",
  standaloneSections: [
    "TOP LEVEL GUIDES AND MANUALS"
  ],
  collapsibleGroups: [
    {
      title: "Component Tree Diagrams",
      sections: ["FAMILY TREE/PARTS LISTS/COMPONENT NUMBERS"]
    },
    {
      title: "System Block Diagrams",
      sections: ["SYSTEM BLOCK DIAGRAMS", "DETAIL BLOCK DIAGRAMS"]
    },
    {
      title: "System Interconnect Diagrams",
      sections: ["SYSTEM INTERCONNECT DIAGRAMS"]
    },
    {
      title: "Component Diagrams & Schematics",
      sections: ["DRAWINGS AND SUPPORTING DOCUMENTATION"]
    },
    {
      title: "Cable Diagrams",
      sections: ["CABLES"]
    },
    {
      title: "Misc Reference Documents",
      sections: [
        "TEST DOCUMENTS, DIAGNOSTIC AND DEBUGGING TOOLS/GUIDES"
      ]
    }
  ],
  sections: [
    {
      title: "TOP LEVEL GUIDES AND MANUALS",
      kind: "keyValue",
      tableClass: "two-col compact",
      rows: [
        ["Acronym Glossary", L("ACRONYMS", H.acronyms)],
        ["\"TO\"\nTechnical Manual", [L("TO 31R2-2FRC192-1", H.toManual), P("(for BIT errors see page 534+)")]],
        ["System/Subsystem Design Description", L("SSDD", H.ssdd)],
        ["GASNT Troubleshooting Guide", L("DOC", H.troubleGuideDoc)]
      ]
    },
    {
      title: "SYSTEM BLOCK DIAGRAMS",
      tableClass: "thumbnail-table",
      head: ["Description", "CLICK IMAGE TO OPEN IN DETAIL"],
      rows: [
        ["Top Level (Executive)", I("DOC_LINKS/Visio-GASNT%20System%20Architecture%20Block%20Diagrams%20-%20Executive.pdf", "GASN2T_files/image006.jpg", 301, 221, "Top level executive block diagram preview")],
        ["Top Level (Detailed)", I("DOC_LINKS/Visio-GASNT%20System%20Architecture%20Block%20Diagrams%20-%20Top%20Level.pdf", "GASN2T_files/image008.jpg", 301, 195, "Top level detailed block diagram preview")],
        ["Integration and troubleshooting - Network", I("DOC_LINKS/Visio-GASNT%20MIR%20V021.pdf", "GASN2T_files/image010.jpg", 301, 288, "Integration and troubleshooting network preview")]
      ]
    },
    {
      title: "DETAIL BLOCK DIAGRAMS",
      tableClass: "thumbnail-table",
      head: ["Description", "CLICK IMAGE TO OPEN IN DETAIL"],
      rows: [
        ["Fiber Optic Connections (MPG)", I("DOC_LINKS/Visio-GASNT%20MIR%20V011%20-%20MPG%20FIA%20CONNECTIONS.pdf", "GASN2T_files/image012.jpg", 301, 426, "Fiber optic connections preview")],
        ["Rubidium Clock Path", I("DOC_LINKS/Visio-GASNT%20MIR%20V005%20RUBIDIUM.pdf", "GASN2T_files/image014.jpg", 301, 203, "Rubidium clock path preview")],
        ["ACU (Marlborough)", I(H.acuBlock, "GASN2T_files/image016.jpg", 300, 210, "ACU block diagram preview")],
        ["ACU DEBUG AID (Manuel)", I("DOC_LINKS/Visio-ACU%20STUDY%20V006.pdf", "GASN2T_files/image018.gif", 300, 244, "ACU debug aid preview")],
        ["MPG - ACU FIA SERDES TRANSFERS (Bob Peterson)", I("DOC_LINKS/FIA%20SERDES%20Diagram,%20FIA-1,%20FIA-2%20(-6),%20Rev%20-.pdf", "GASN2T_files/image020.jpg", 306, 186, "FIA SERDES transfers preview")]
      ]
    },
    {
      title: "SYSTEM INTERCONNECT DIAGRAMS",
      tableClass: "thumbnail-table",
      head: ["Description", "CLICK IMAGE TO OPEN IN DETAIL"],
      rows: [
        ["Total\nGASNT System Interconnect", I("DOC_LINKS/GASNT%20TOTAL%20INTERCONNECT%20DIAGRAM%20SDA2450928_e_all.pdf", "GASN2T_files/image022.jpg", 300, 172, "Total GASNT system interconnect preview")],
        ["MEC\nInterconnect", I("DOC_LINKS/MEC%20INTERNAL%20INTERCONNECT%20DIAGRAM%20sda2314509_k_all.pdf", "GASN2T_files/image024.jpg", 300, 225, "MEC interconnect preview")],
        ["MEC Side\nPanel Interconnect (waterfall)", I("DOC_LINKS/MEC%20HEMP%20ENCLOSURE%20CABINET%20INTERCONNECT%20DIAGRAM%20SDA4274605_a_all.pdf", "GASN2T_files/image026.jpg", 300, 287, "MEC side panel interconnect preview")],
        ["ACU\nInterconnect", I(H.acuInterconnect, "GASN2T_files/image028.jpg", 299, 141, "ACU interconnect preview")],
        ["Antenna\nSystem Interconnect Diagram", I("DOC_LINKS/ANTENNA%20SYSTEM%20BLOCK%20INTERCONNECT%20CONNECTOR%20DIAGRAM%20SDA2450962_d_all.pdf", "GASN2T_files/image030.jpg", 300, 176, "Antenna system interconnect preview")],
        ["Antenna\nSystem Wiring Diagram", I("DOC_LINKS/ANTENNA%20SYSTEM%20BLOCK%20INTERCONNECT%20WIRING%20DIAGRAM%20SDA7249897_f_all.pdf", "GASN2T_files/image032.jpg", 300, 226, "Antenna system wiring preview")],
        ["SATCOM\nSystem ESS Test Station", I(H.essTest, "GASN2T_files/image034.jpg", 299, 217, "ESS system test interconnect preview")],
        ["SATCOM\nSystem Function Test Station", I("DOC_LINKS/SATCOM%20INTERCONNECT%20TEST%20sdh502950_b_all.pdf", "GASN2T_files/image036.jpg", 301, 190, "SATCOM interconnect test preview")],
        ["GASNT TEST\nRACK Interconnect", I(H.testRackOld, "GASN2T_files/image038.jpg", 299, 192, "GASNT test rack interconnect preview")]
      ]
    },
    {
      title: "FAMILY TREE/PARTS LISTS/COMPONENT NUMBERS",
      tableClass: "visual-table",
      head: ["CLICK IMAGE TO OPEN IN DETAIL"],
      rows: [
        [I("DOC_LINKS/Family%20Tree%20v05B%20-DRAFT.pdf", "GASN2T_files/image040.jpg", 601, 335, "Family tree preview", true)],
        [[I("DOC_LINKS/global%20breakdown.xlsx", "GASN2T_files/image042.jpg", 598, 229, "Global breakdown preview", true), P("(Adam Palermo)")]],
        [L("TOP Parts List PLA4274708", H.topPartsVisual)],
        [L("System Indentured BOM", H.systemBom)]
      ]
    },
    {
      title: "DRAWINGS AND SUPPORTING DOCUMENTATION",
      kind: "matrix",
      tableClass: "matrix",
      wrapClass: "table-wrap",
      head: ["System", "Unit", "", "", "", "", "", ""],
      rows: [
        R("MEC", "MEC", L("Mech Schematic - Cabinet", "DOC_LINKS/POWER%20DISTRIBUTION%20SUBSYSTEM%20a2452025_b_all.pdf"), "", "", "", "", ""),
        R("", "SMS", L("Mech Schematic", H.serverMech), L("Parts List", H.serverParts), L("Spec", H.serverSpec), "", "", ""),
        R("", "MPS", L("Mech Schematic", H.serverMech), L("Parts List", H.serverParts), L("Spec", H.serverSpec), "", "", ""),
        R("", "MDU", "", L("Elec Schematic", H.mduSchematic), L("PWA", H.mduPwa), L("Mech Schematic", "DOC_LINKS/MDU%20MECHANICAL%20a2463194_d_all.pdf"), L("Parts List", "DOC_LINKS/MDU%20PARTS%20LIST%20pla2463194-1_e_all.pdf"), ""),
        R("", "KDS", L("Elec Schematic", "DOC_LINKS/KDS%20CCA%20SCHEMATIC%200n836174_c_all_FOUO.pdf"), L("CCA", "DOC_LINKS/KDS%20CCA%2000N836177_f_all_FOUO.pdf"), L("Parts List", "DOC_LINKS/KDS%20CCA%20PARTS%20LIST%20p1on836177_1_f_all%20FOVO.pdf"), "", "", ""),
        R("", "DLP", L("Interconnect", "DOC_LINKS/DLP%20INTERCONNECT%20DIAGRAM%20SDA2463191_d_all.pdf"), L("Elec Schematic", "DOC_LINKS/DLP%20MDU%20SCHEMATIC%20sda2905470_e_all%20(1).pdf"), L("PWA", H.mduPwa), L("Mech Schematic", "DOC_LINKS/DLP%20MECHANICAL%20a2463191_e_all.pdf"), [L("Parts List - Backplane", H.dlpBackplane), L("Parts List", "DOC_LINKS/DLP%20PARTS%20LIST%20p1a2463191-1_d_all.pdf")], ""),
        R("", "KY-100M", "", "", "", "", "", ""),
        R("", "KIV-7M", L("Cable Spec", "DOC_LINKS/KIV7%20CONNECTOR%20CABLE%20ASSEMBLY%20SPEC%20a4624827_c_all.pdf"), L("Tray PS", "DOC_LINKS/KIV7%20POWER%20SUPPLY%20ASSEMBLY%20MECHANICAL%20A5275190_c_a11.pdf"), L("Manual", "DOC_LINKS/KIV-7M%20Manual-Rev%20E%20NOT%20PDM.pdf"), "", "", ""),
        R("", "PDU", L("Interconnect", "DOC_LINKS/MEC%20PDU%20INTERCONNECT%20DIAGRAM%20sda420722_e_all.pdf"), L("Mechanical", "DOC_LINKS/MEC%20PDU%20MECHANICAL%20a4207222_h_all.pdf"), L("Parts List", "DOC_LINKS/MEC%20PDU%20POWER%20DISTRIBUTION%20PARTS%20LIST%20p1a4207222-1_g_all.pdf"), "", "", ""),
        R("", "KOV-81", L("Interconnect", "DOC_LINKS/KOV81%20INTERCONNECT%200N836162_b_all_1-25-21.pdf"), L("Elec Schematic", "DOC_LINKS/KOV81%20ACCG%20ELECTRICAL%20SCHEMATIC%200N836167_f.pdf"), L("Mechanical", "DOC_LINKS/KOV81%20MECHANICAL%20on836158_d_all.pdf"), [L("Parts List", "DOC_LINKS/KVO81%20PARTS%20LIST%20p10N836158-1_e_all.pdf"), L("ACCG Parts List", "DOC_LINKS/KOV81%20ACCG%20PARTS%20LIST%20p10n836165_1_y_a11%20FOUO.pdf")], L("ACCG Cable Assembly", "DOC_LINKS/KOV81%20CABLE%20ASSEMBLY%200N836163_f_all.pdf"), ""),
        R("", "- ACCG/KGV-136B/CTIA/ECU", [L("ACCG Assembly", "DOC_LINKS/KOV81%20ACCG%20ASSEMBLY%20on836165_f.pdf"), L("ACCG PWB", "DOC_LINKS/KOV81%20ACCG%20PWB%200N836166_e_all_FUU0.pdf")], L("CSG FPGA ICD", "DOC_LINKS/KOV81%20ACCG%20CSG%20FPGA%20HW%20SW%20ICD%20NOT%20FROM%20PDM.pdf"), L("CSGRM FPGA DD", "DOC_LINKS/KOV81%20ACCG%20CSGRM%20FPGA%20Design%20Description.pdf"), L("ACCG Design Memo", "DOC_LINKS/KOV81%20ACCG%20Design%20Memo%20NO%20PDM.pdf"), L("FDX FPGA ICD", "DOC_LINKS/KOV81%20ACCG%20FDX%20FPGA%20%20HW%20SW%20ICD.pdf"), L("MAF FPGA ICD", "DOC_LINKS/KOV81%20ACCG%20MAF%20FPGA%20HW%20SW%20ICD.pdf")),
        R("", "MPG", L("Interconnect", "DOC_LINKS/MPG%20INTERCONNECT%20DIAGRAM%20SDA2080872_b_all.pdf"), L("Elec Schematic", "DOC_LINKS/MPG%20OLD%20VERSION%20SCHEMATIC%20LOOK%20FOR%20NEW%20IN%20PDM%20SDA2079676_e_all.pdf"), L("Mech Schem - Front Panel", "DOC_LINKS/MPG%20FRONT%20PANEL%20MECHANICAL%20a2079419_d_all.pdf"), "", L("Parts List", "DOC_LINKS/MPG%20PARTS%20LIST%20pla2080872-1_f_all.pdf"), L("Parts List - Backplane", "DOC_LINKS/MPG%20BACKPLANE%20PARTS%20LIST%20pla2079676-1_n_all.pdf")),
        R("ACU", "ACU", L("Interconnect", H.acuInterconnect), L("Elec Schematic", "DOC_LINKS/ACU%20BACKPLANE%20ELECTRICAL%20SCHEMATIC%20sdA2463504_d_all.pdf"), [L("PWA", "DOC_LINKS/ACU%20BACKPLANE%20PWA%20MECHANICAL%20a2463504_l_all.pdf"), L("PWB", "DOC_LINKS/ACU%20BACKPLANE%20PWB%20pwa2463504_g_all.pdf")], L("Chassis", "DOC_LINKS/ACU%20MECHANICAL%20CHASSIS%20ASSEMBLY%20a2463432_e_all.pdf"), L("Block Diagram", H.acuBlock), ""),
        R("", "- GMUP", L("Elec Schematic", "DOC_LINKS/ACU%20GMUP%20ELECTRICAL%20SCHEMATIC%20sdh488305_e_all.pdf"), "", "", "", "", ""),
        R("", "- RF Backplane", L("Elec Schematic", "DOC_LINKS/ACU%20RF%20PLATE%20SCHEMATIC%20DIAGRAM%20SDH475770_a_all.pdf"), L("Mechanical", "DOC_LINKS/ACU%20RF%20PLATE%20MECHANICAL%20h490061_c_all.pdf"), L("Assembly", "DOC_LINKS/ACU%20RF%20PLATE%20ASSEMBLY%20h475770_e_all.pdf"), "", "", ""),
        R("", "- CSM", L("Elec Schematic", "DOC_LINKS/ACU%20CSM%20SCHEMATIC%20sdh477747_h_all.pdf"), "", "", "", "", ""),
        R("", "- MOD", L("Elec Schematic", "DOC_LINKS/ACU%20MOD%20SCHEMATIC%20sdh477745_b_all.pdf"), "", "", "", "", ""),
        R("", "- RVM", L("Elec Schematic", "DOC_LINKS/ACU%20RVM%20SCHEMATIC%20sdh477746_b_all.pdf"), "", "", "", "", ""),
        R("", "- APU", L("Parts List", "DOC_LINKS/ACU%20APU%20PARTS%20LIST%20plh476823_2_e_all.pdf"), "", "", "", "", ""),
        R("", "- Cables", L("Cable Design", H.acuCables), "", "", "", "", ""),
        R("Shared CCAs", "MUP", "", "", "", "", "", ""),
        R("", "FIA", L("Elec Schematic", "DOC_LINKS/FIA%20ELECTRICAL%20SCHEMATIC%20SDA2900065_d_all_FOUO.pdf"), [L("Assembly", "DOC_LINKS/FIA%20ASSEMBLY%20a2643758_c_all.pdf"), L("PWA", "DOC_LINKS/FIA%20PWB%20PWA2900065_f_all_FOUO.pdf")], L("FPGA Design", "DOC_LINKS/FIA%20FPGA%20Design%20Description%20DDA2434588%20NOT%20FROM%20PDM.pdf"), [L("Detail", "DOC_LINKS/FIA%20CCA%20ASSEMBLY%20BOOKMARKED%20A2900065_h_all_FOUO.pdf"), L("GPS Detail", "DOC_LINKS/FIA%20SCHEMATIC%20DIAGRAM%20sda2643758_a_all.pdf")], L("Block Diagrams", "DOC_LINKS/FIA_Block_Diagram.pdf"), L("Connections FIBER", "DOC_LINKS/Visio-GASNT%20MIR%20V005%20PAGE%201%20BMPG%20FIA%20CONNECTIONS.pdf")),
        R("", "BBIC", L("FPGA Design", "DOC_LINKS/BBIC%20FPGA%20DESIGN%20DESCRIPTION%20da2538590_a_all.pdf"), L("Parts List", "DOC_LINKS/BBIC%20PARTS%20LIST%20plh475758_4_c_all.pdf"), "", "", "", ""),
        R("External Units", "MC", "", "", "", "", "", ""),
        R("", "NNC", "", "", "", "", "", ""),
        R("", "NNC Printer", "", "", "", "", "", "")
      ]
    },
    {
      title: "CABLES",
      tableClass: "cables",
      wrapClass: "table-wrap narrow-wrap",
      head: ["CABLES (WXX may be found in multiple drawings, verify manually which one is the one of interest)", "DRAWING", "NOTES"],
      rows: [
        ["W19\nW21\nW22\nW43\nW46\nW51\nW52\nW53\nW54\nW55", L("0N836190", "DOC_LINKS/MEC%20INTERCONNECT%20CABLE%20DESIGNS%200n836190_f_all_1-25-21.pdf"), "COPPER KDS,KOV-81,KY-100,KIV-7,MPG,DLP"],
        ["1\n2\n3\n4\n5\n6\n7", [L("A4110763", "DOC_LINKS/FIBER%20CABLE%20DESIGNS%20NOT%20YET%20RELEASED%20IN%20PDM%20a4110763_c_all.pdf"), L("A4110763", "DOC_LINKS/FIBER%20CABLE%20DESIGNS%20NOT%20YET%20RELEASED%20IN%20PM%20a4110763_c_all.pdf")], "FIBER OUTSOURCED\nINSIDE OF LRUs"],
        ["W6DP (not in interconnect ??)\nW10 (not in interconnect ??)\nW27\nW33", [L("0N836277", "DOC_LINKS/MEC%20INTERCONNECT%20CABLE%20DESIGNS%20EXTRA%20N836277_a_all.pdf"), L("0N836277", "DOC_LINKS/MEC%20INTERCONNECT%20CABLE%20DESIGNS%20EXTRA%20on836277_a_all.pdf")], "COPPER - KOV-81<->MPG"],
        ["W01\nW02\nW03\nW04\nW05\nW06\nW07\nW08\nW10\nW12\nW13\nW14\nW15\nW16\nW18\nW20\nW28\nW31\nW36\nW40\nW41\nW42\nW45", L("A4207144", "DOC_LINKS/MEC%20INTERCONNECT%20CABLE%20DESIGN%20EXTRA%20NOT%20RELEASED%20a4207144_1_all.pdf"), "COPPER, E/N, POWER, MPDU,DLP,MEC,MPS,SMS,SLP,MPG,KY-100,KIV-7,KDS"],
        ["W17\nW25\nW26\nW32\nW34\nW35\nW39\nW48\nW49 (not supplied with INC1)", L("A4246403", "DOC_LINKS/MEC%20INTERCONNECT%20FIBER%20OPTIC%20CABLE%20DESIGNS%20a4246403_e_all.pdf"), "FIBER OUTSOURCED\nLRU TO LRU, LRU TO MEC-INSIDE-WATERFALL"],
        ["W2\nW7\nW11\nW14\nW38", L("D3503802", "DOC_LINKS/MEC%20INTERCONNECT%20CABLE%20DESIGNS%20EXTRA%20d3503802_b_all.pdf"), "COPPER DLP TO MPG, INTRA DLP, INTRA MPG"],
        ["W29\nW30\nW37\nW57\nW58\nW59", L("D3570041", "DOC_LINKS/MEC%20INTERCONNECT%20CABLE%20DESIGNS%20EXTRA%20d3570041_d_all.pdf"), "COPPER MPG, DLP, KIV-7Ms"],
        ["ACU CABLES", L("A4249379", H.acuCables), ""]
      ]
    },
    {
      title: "TEST DOCUMENTS, DIAGNOSTIC AND DEBUGGING TOOLS/GUIDES",
      tableClass: "mixed-table",
      head: ["", "CLICK IMAGE TO OPEN IN DETAIL"],
      rows: [
        ["System Build and Test Flow", I("DOC_LINKS/HEMP%20FOCUS%20GASNT%20Assy_Test%20Flow%2020210311%20(Pages%20omitted).pdf", "GASN2T_files/image044.jpg", 301, 192, "System build and test flow preview")],
        ["Antenna Test Requirements", L("TRA2555686", "DOC_LINKS/ANTENA%20TEST%20REQUIREMENTS%20tra2555686_a_all.pdf")],
        ["Console Test Station Interconnect", "SDC6503532 (Verify first)"],
        ["ESS System Test Interconnect", I(H.essTest, "GASN2T_files/image034.jpg", 299, 217, "ESS system test interconnect preview")],
        ["GASNT TEST REQUIREMENTS (Includes SW)", L("TRD3365766", "DOC_LINKS/GASNT%20TEST%20REQUIREMENTS%20FROM%20PDM%20trd3365766_b_all.pdf")],
        ["GASNT TEST RACK Interconnect", I(H.testRackNew, "GASN2T_files/image038.jpg", 299, 192, "GASNT test rack interconnect preview")],
        ["TEST MATRIX", L("TEST MATRIX", "DOC_LINKS/TEST%20MATRIX%20LMTPA4274708.pdf")],
        ["FAB-T Bit Error Tests", L("BIT", "DOC_LINKS/BIT%20report.pdf")],
        ["Data Recording Software", L("DRS", "DOC_LINKS/DRS%20Users%20Guide%20NOT%20PDM.pdf")],
        ["Bit-O-Matic", "[get screen captures]"],
        ["BITSIM", L("Debugging Bit Equations", "DOC_LINKS/Debugging%20BIT%20Equations%20with%20BITSIM%20-%20Rev%203.pdf")],
        ["", L("Setup/Install", "HTML_SUBCONTENT/BitsimSetupHelp.html")],
        ["", L("BitSim Commands", "HTML_SUBCONTENT/BitsimCommandHelp.html")],
        ["Fiber Cleaning", [L("Fiber Cleaning", "HTML_SUBCONTENT/FIBER%20CLEANING%20V001.pdf"), L("Fiber Cleaning", "HTML_SUBCONTENT/FIBER%20CLEANING%20V001.pdf")]],
        ["GASNT Full Fiber Routing (Largo - Dan Sellman)", L("EXCEL", "HTML_SUBCONTENT/GASNT%20full%20fiber%20routing.xlsx")],
        ["Fiber Pinouts for Test Rack (Marl - James Nicholson)", "EXCEL"],
        ["MEC Interconnect (Largo - Manuel Rodriguez)", L("EXCEL", "HTML_SUBCONTENT/GASNT%20INTERCONNECT%20V037.xlsx")],
        ["Ethernet Interconnect (Mar1)", L("LINK", "DOC_LINKS/Visio-GASNT%20MIR%20V011%20-%20MRL.pdf")],
        ["Built In Test Set", L("LINK", "HTML_SUBCONTENT/BUILT%20IN%20TEST%20SET.xlsx")],
        ["Issue Tracking Log Location", L("\\\\oatmeal.mrl.us.ray.com\\gasnt_proj\\90 Eng Support to Production\\AESM Issues", "../../90%20Eng%20Support%20to%20Production/AESM%20Issues")],
        ["GASNT TroubleShooting Guide", L("LINK", "DOC_LINKS/GASNT%20Troubleshooting%20Guide_Rev%20-%20Locked.pdf")],
        ["\"TO\"\nTechnical Manual", [L("TO 31R2-2FRC192-1", H.toManual), P("(for BIT errors see page 534+)")]],
        ["ATP 2 NI MAX Black Side Instrument Settings", L("Black Side Instrument NI MAX Settings", "DOC_LINKS/Black%20Side%20NI%20Max%20Intrument%20Settings.xlsx")],
        ["ESS Ni Max Black Side Instrument Settings", "TBD"],
        ["Reprogramming the BBIs", L("FNGASNT-017", "DOC_LINKS/FNGASNT-017.pdf")],
        ["KOV-81 Boot Failure at Cold - Final Report", L("Cold Boot Problem", "HTML_SUBCONTENT/GASNT%20KOV-81%20ACCG%20COLD%20BOOT%20FAILURE%20V005.pdf")]
      ]
    }
  ]
};
