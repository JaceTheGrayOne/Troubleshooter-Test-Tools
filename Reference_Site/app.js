(function () {
  const data = window.GASNT_DATA;
  const app = document.getElementById("app");

  function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) addContent(node, text);
    return node;
  }

  function addText(parent, text) {
    String(text).split("\n").forEach((part, index) => {
      if (index) parent.appendChild(document.createElement("br"));
      parent.appendChild(document.createTextNode(part));
    });
  }

  function addContent(parent, content) {
    if (content === null || content === undefined || content === "") return;
    if (Array.isArray(content)) {
      content.forEach(item => addContent(parent, item));
      return;
    }
    if (typeof content === "string" || typeof content === "number") {
      addText(parent, content);
      return;
    }
    if (content.p !== undefined) {
      parent.appendChild(el("p", "", content.p));
      return;
    }
    if (content.href && content.src) {
      const a = el("a", content.wide ? "wide-thumb" : "thumb");
      a.href = content.href;
      const img = document.createElement("img");
      img.src = content.src;
      img.width = content.width;
      img.height = content.height;
      img.alt = content.alt || "";
      a.appendChild(img);
      parent.appendChild(a);
      return;
    }
    if (content.href) {
      const a = el("a", "", content.label);
      a.href = content.href;
      parent.appendChild(a);
      return;
    }
  }

  function cellSpec(content) {
    if (content && typeof content === "object" && !Array.isArray(content) && Object.prototype.hasOwnProperty.call(content, "value")) {
      return content;
    }
    return { value: content, color: "" };
  }

  function addCell(row, tag, content, className) {
    const spec = cellSpec(content);
    const cell = el(tag, className || "", spec.value);
    if (spec.color) cell.style.backgroundColor = spec.color;
    row.appendChild(cell);
    return cell;
  }

  function addRow(table, cells, tags, classes) {
    const tr = document.createElement("tr");
    cells.forEach((content, index) => {
      addCell(tr, tags[index] || "td", content, classes?.[index]);
    });
    table.appendChild(tr);
  }

  function groupSpan(rows, start) {
    let span = 1;
    while (start + span < rows.length && !cellSpec(rows[start + span][0]).value) span += 1;
    return span;
  }

  function addMatrixRows(table, rows) {
    rows.forEach((row, rowIndex) => {
      const tr = document.createElement("tr");
      const group = cellSpec(row[0]).value;
      if (group) tr.className = "section-start";
      if (group) addCell(tr, "th", row[0], "group-cell").rowSpan = groupSpan(rows, rowIndex);
      row.slice(1).forEach((content, index) => {
        addCell(tr, index === 0 ? "th" : "td", content, index === 0 ? "unit-cell" : "");
      });
      table.appendChild(tr);
    });
  }

  function renderTable(section) {
    const table = el("table", section.tableClass);
    if (section.head) addRow(table, section.head, section.head.map(() => "th"));
    if (section.kind === "matrix") {
      addMatrixRows(table, section.rows);
      if (!section.wrapClass) return table;
      const wrap = el("div", section.wrapClass);
      wrap.appendChild(table);
      return wrap;
    }
    section.rows.forEach(row => {
      let tags = row.map(() => "td");
      if (section.kind === "keyValue") tags[0] = "th";
      addRow(table, row, tags);
    });
    if (!section.wrapClass) return table;
    const wrap = el("div", section.wrapClass);
    wrap.appendChild(table);
    return wrap;
  }

  function renderSection(section, showTitle = true) {
    const node = document.createElement("section");
    if (showTitle) {
      node.appendChild(el("h2", "", section.title));
      if (section.subtitle) node.appendChild(el("h3", "", section.subtitle));
    }
    node.appendChild(renderTable(section));
    return node;
  }

  function renderGroup(group, sectionsByTitle) {
    const details = el("details", "collapsible");
    details.appendChild(el("summary", "collapsible-title", group.title));
    const body = el("div", "collapsible-body");
    group.sections.forEach(title => {
      const section = sectionsByTitle.get(title);
      if (section) body.appendChild(renderSection(section, false));
    });
    details.appendChild(body);
    return details;
  }

  function renderHeader() {
    app.appendChild(el("div", "revision-banner", data.banner));
    const header = el("header", "mast");
    header.appendChild(el("h1", "", data.title));
    const titleTable = el("table", "title-table");
    addRow(titleTable, [data.subtitle], ["td"]);
    header.appendChild(titleTable);
    const fig = el("figure", "overview");
    const img = document.createElement("img");
    Object.assign(img, data.overview);
    fig.appendChild(img);
    header.appendChild(fig);
    app.appendChild(header);
  }

  renderHeader();
  const sectionsByTitle = new Map(data.sections.map(section => [section.title, section]));
  data.standaloneSections.forEach(title => {
    const section = sectionsByTitle.get(title);
    if (section) app.appendChild(renderSection(section));
  });
  data.collapsibleGroups.forEach(group => app.appendChild(renderGroup(group, sectionsByTitle)));
  app.appendChild(el("footer", "site-footer", data.footer));
})();
