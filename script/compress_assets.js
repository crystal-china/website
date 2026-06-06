import { brotliCompressSync, gzipSync } from "node:zlib";
import { readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import path from "node:path";

const ASSET_ROOT = path.resolve("public/assets");
const COMPRESSIBLE_EXTENSIONS = new Set([
    ".css",
    ".html",
    ".js",
    ".json",
    ".svg",
    ".txt",
    ".wasm",
    ".xml",
    ".yml",
]);

function walk(dir) {
    for (const entry of readdirSync(dir)) {
        const absolutePath = path.join(dir, entry);
        const stats = statSync(absolutePath);

        if (stats.isDirectory()) {
            walk(absolutePath);
            continue;
        }

        const ext = path.extname(absolutePath);
        if (!COMPRESSIBLE_EXTENSIONS.has(ext)) continue;

        const fileContent = readFileSync(absolutePath);
        writeFileSync(`${absolutePath}.gz`, gzipSync(fileContent));
        writeFileSync(`${absolutePath}.br`, brotliCompressSync(fileContent));
    }
}

walk(ASSET_ROOT);
