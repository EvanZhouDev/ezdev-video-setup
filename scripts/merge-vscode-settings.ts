import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";

const [localPath, targetPath] = Bun.argv.slice(2);

if (!localPath || !targetPath) {
  console.error("Usage: bun run scripts/merge-vscode-settings.ts <localSettingsPath> <targetSettingsPath>");
  process.exit(1);
}

const TRAILING_COMMA_RE = /,(?=\s*[}\]])/g;

function stripJsonc(input: string): string {
  const output: string[] = [];
  let index = 0;
  let inString = false;
  let escaped = false;

  while (index < input.length) {
    const char = input[index];
    const nextChar = index + 1 < input.length ? input[index + 1] : "";

    if (inString) {
      output.push(char);
      if (escaped) {
        escaped = false;
      } else if (char === "\\") {
        escaped = true;
      } else if (char === "\"") {
        inString = false;
      }
      index += 1;
      continue;
    }

    if (char === "\"") {
      inString = true;
      output.push(char);
      index += 1;
      continue;
    }

    if (char === "/" && nextChar === "/") {
      index += 2;
      while (index < input.length && input[index] !== "\r" && input[index] !== "\n") {
        index += 1;
      }
      continue;
    }

    if (char === "/" && nextChar === "*") {
      index += 2;
      while (index + 1 < input.length && !(input[index] === "*" && input[index + 1] === "/")) {
        index += 1;
      }
      if (index + 1 < input.length) {
        index += 2;
      } else {
        index = input.length;
      }
      continue;
    }

    output.push(char);
    index += 1;
  }

  return output.join("");
}

function removeTrailingCommas(input: string): string {
  let cleaned = input;

  while (true) {
    const updated = cleaned.replace(TRAILING_COMMA_RE, "");
    if (updated === cleaned) {
      return cleaned;
    }
    cleaned = updated;
  }
}

function loadJsonObject(filePath: string): Record<string, unknown> {
  let rawText = "";

  try {
    rawText = readFileSync(filePath, "utf8");
  } catch (error) {
    const err = error as NodeJS.ErrnoException;
    if (err.code === "ENOENT") {
      return {};
    }
    throw error;
  }

  if (rawText.trim() === "") {
    return {};
  }

  const normalized = removeTrailingCommas(stripJsonc(rawText));
  const parsed = JSON.parse(normalized);

  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error(`${filePath} must contain a JSON object.`);
  }

  return parsed as Record<string, unknown>;
}

try {
  const existing = loadJsonObject(targetPath);
  const incoming = loadJsonObject(localPath);
  const merged = { ...existing, ...incoming };

  mkdirSync(dirname(targetPath), { recursive: true });
  writeFileSync(targetPath, JSON.stringify(merged, null, 2) + "\n", "utf8");

  console.log(
    `Merged ${Object.keys(incoming).length} local setting(s) into ${targetPath}`,
  );
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`Settings merge error: ${message}`);
  process.exit(1);
}
