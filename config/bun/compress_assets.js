import { mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import path from "node:path";
import { brotliCompressSync, gzipSync } from "node:zlib";

// Lucky copies staticDirs to outDir itself, while js/css come from Bun.build().
// We compress both sources here so production assets always have .gz/.br sidecars.
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

function compressFile(filePath, content) {
    writeFileSync(`${filePath}.gz`, gzipSync(content));
    writeFileSync(`${filePath}.br`, brotliCompressSync(content));
}

function compressExistingFiles(dir) {
    // Static assets already exist on disk by the time onEnd runs.
    for (const entry of readdirSync(dir)) {
        const absolutePath = path.join(dir, entry);
        const stats = statSync(absolutePath);

        if (stats.isDirectory()) {
            compressExistingFiles(absolutePath);
            continue;
        }

        const ext = path.extname(absolutePath);
        if (!COMPRESSIBLE_EXTENSIONS.has(ext)) continue;
        if (absolutePath.endsWith(".gz") || absolutePath.endsWith(".br")) continue;

        compressFile(absolutePath, readFileSync(absolutePath));
    }
}

function fingerprintName(name, ext, content, fingerprint) {
    if (!fingerprint) return `${name}${ext}`;

    const hash = Bun.hash(content).toString(16).slice(0, 8);
    return `${name}-${hash}${ext}`;
}

async function compressBuildOutputs(result, outDir, fingerprint) {
    // JS/CSS are still available as build outputs, so we derive the same final
    // fingerprinted filenames Lucky writes and emit matching compressed files.
    for (const output of result.outputs) {
        const ext = path.extname(output.path);
        if (![".js", ".css"].includes(ext)) continue;

        const assetType = ext.slice(1);
        const baseName = path.basename(output.path, ext);
        let content = await output.text();
        const fileName = fingerprintName(baseName, ext, content, fingerprint);

        if (ext === ".js") {
            content = content.replace(
                /\/\/# sourceMappingURL=\S+/,
                `//# sourceMappingURL=${fileName}.map`,
            );
        }

        const targetDir = path.join(outDir, assetType);
        const targetPath = path.join(targetDir, fileName);

        mkdirSync(targetDir, { recursive: true });
        compressFile(targetPath, content);
    }
}

export default function compressAssetsPlugin({ config, prod, fingerprint }) {
    return {
        name: "compress-assets",
        setup(build) {
            if (!prod) return;

            build.onEnd(async (result) => {
                const outDir = path.resolve(config.outDir);

                compressExistingFiles(outDir);
                await compressBuildOutputs(result, outDir, fingerprint);
            });
        },
    };
}
