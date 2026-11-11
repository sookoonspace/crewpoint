/**
 * Reads CSV text into rows of cells (RFC 4180): quoted cells may hold commas,
 * line breaks and doubled quotes. A byte-order mark and blank lines are
 * dropped. Throws on an unclosed quote.
 */
export function parseCsv(text: string): string[][] {
  const input = text.startsWith("﻿") ? text.slice(1) : text;
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = "";
  let quoted = false;
  let i = 0;
  const endRow = () => {
    row.push(cell);
    if (row.length > 1 || row[0] !== "") rows.push(row);
    row = [];
    cell = "";
  };
  while (i < input.length) {
    const ch = input[i];
    if (quoted) {
      if (ch === "\"") {
        if (input[i + 1] === "\"") {
          cell += "\"";
          i += 2;
          continue;
        }
        quoted = false;
      } else {
        cell += ch;
      }
      i++;
      continue;
    }
    if (ch === "\"" && cell === "") {
      quoted = true;
    } else if (ch === ",") {
      row.push(cell);
      cell = "";
    } else if (ch === "\n" || ch === "\r") {
      if (ch === "\r" && input[i + 1] === "\n") i++;
      endRow();
    } else {
      cell += ch;
    }
    i++;
  }
  if (quoted) throw new Error("A quoted cell is never closed.");
  if (cell !== "" || row.length > 0) endRow();
  return rows;
}

const FORMULA_LEADS = new Set(["=", "+", "-", "@", "\t", "\r"]);

/**
 * Makes a cell safe to open in a spreadsheet, which would run a cell
 * starting with one of these as a formula. A leading apostrophe makes it
 * text. Matches the app's `neutraliseCsvCell`.
 */
export function neutraliseCell(cell: string): string {
  return cell.length > 0 && FORMULA_LEADS.has(cell[0]) ? `'${cell}` : cell;
}

/** Rows as CSV, every cell neutralised and quoted where needed. */
export function toCsv(rows: string[][]): string {
  return rows.map((row) => row.map((raw) => {
    const cell = neutraliseCell(raw);
    return /[",\r\n]/.test(cell) ? `"${cell.replace(/"/g, "\"\"")}"` : cell;
  }).join(",")).join("\r\n") + "\r\n";
}
