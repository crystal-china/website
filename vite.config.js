// vite.config.js
import { defineConfig, loadEnv } from "vite";
import { resolve } from "path";
import crypto from "crypto";
import path from "path";
import fs from "fs";
const zlib = require("zlib");
import viteCompression from "vite-plugin-compression";
import inject from "@rollup/plugin-inject";

export default defineConfig(({ command, mode }) => {
    const isWatch = mode === "watch";
    const outDir = "dist";

    const env = loadEnv(mode, process.cwd(), "");

    return {
        define: {
            IS_WATCH_MODE: JSON.stringify(isWatch), // 传递为全局常量
            __FIREBASE_CONFIG__: JSON.stringify({
                apiKey: env.VITE_FIREBASE_API_KEY,
                authDomain: env.VITE_FIREBASE_AUTH_DOMAIN,
                projectId: env.VITE_FIREBASE_PROJECT_ID,
                storageBucket: env.VITE_FIREBASE_STORAGE_BUCKET,
                messagingSenderId: env.VITE_FIREBASE_MESSAGING_SENDER_ID,
                appId: env.VITE_FIREBASE_APP_ID,
                measurementId: env.VITE_FIREBASE_MEASUREMENT_ID,
            }),
        },
        build: {
            outDir: outDir, // 打包后的输出目录
            rollupOptions: {
                input: {
                    "js/app.js": resolve(__dirname, "src/js/app.js"), // 指定入口文件
                    "css/app.css": resolve(__dirname, "src/css/app.scss"), // 指定 CSS 文件
                },
                output: {
                    entryFileNames: isWatch ? "js/app.js" : "js/app-[hash].js",
                    chunkFileNames: isWatch ? "[name].js" : "[name]-[hash].js", // 动态导入的 JS 文件名
                    assetFileNames: isWatch
                        ? "[name].[ext]"
                        : "[name]-[hash].[ext]", // 静态资源（例如 CSS）命名规则，带 hash
                },
            },
            manifest: true,
            watch: isWatch,
            minify: !isWatch,
            sourcemap: isWatch, // 开启 sourcemap 便于调试
        },
        css: {
            postcss: {
                plugins: [
                    require("autoprefixer"), // 自动添加浏览器前缀
                    ...(isWatch
                        ? []
                        : [require("cssnano")({ preset: "default" })]),
                ],
            },
            preprocessorOptions: {
                scss: {
                    // 直接在 app.scss 中，按照 $dynamic-color 使用
                    additionalData: `
                    $dynamic-color: #63b3ed;
        `,
                },
            },
        },
        plugins: [
            ...(mode !== "watch"
                ? [
                      viteCompression({ algorithm: "gzip", ext: ".gz" }),
                      viteCompression({
                          algorithm: "brotliCompress",
                          ext: ".br",
                      }),
                  ]
                : []),
            inject({
                exclude: ["src/**/*.scss", "src/**/*.css"],
                htmx: "htmx.org",
                _hyperscript: "hyperscript.org",
                pasteImage: "./pasteImage",
                copyCodeButton: "./copyCodeButton.js",
                initializeApp: ["firebase/app", "initializeApp"],
                getAnalytics: ["firebase/analytics", "getAnalytics"],
                logEvent: ["firebase/analytics", "logEvent"],
                Viewer3D: "./viewer3d.js",
                // 这里我修改了源码，在最后加了一行才 `export default stork;` 才 import 成功
                stork: "./stork.js",
                mixManifest: "virtual:mix-manifest",
            }),
            {
                name: "generate-mix-manifest",
                enforce: "post",
                generateBundle(_, bundle) {
                    const mixManifest = {};
                    const publicDir = path.resolve(__dirname, "public");
                    const outputDir = path.resolve(__dirname, outDir);
                    const compressibleFileTypes =
                        /\.(svg|png|jpg|json|js|css|yml)/;

                    // 遍历打包后的文件
                    for (const [fileName, fileInfo] of Object.entries(bundle)) {
                        if (
                            fileInfo.type === "chunk" ||
                            fileInfo.type === "asset"
                        ) {
                            const originalName =
                                fileInfo.name || fileInfo.fileName;
                            // Vite 构建后路径相对于构建目录，需要补充 `/`
                            mixManifest[`/${originalName}`] = `/${fileName}`;
                        }
                    }

                    // 用于压缩文件的函数
                    const compressFile = (filePath, algorithm, extension) => {
                        const fileContents = fs.readFileSync(filePath);
                        let compressedContent;

                        if (algorithm === "gzip") {
                            compressedContent = zlib.gzipSync(fileContents);
                        } else if (algorithm === "brotli") {
                            compressedContent =
                                zlib.brotliCompressSync(fileContents);
                        }

                        fs.writeFileSync(
                            `${filePath}.${extension}`,
                            compressedContent,
                        );
                    };

                    const processPublicFiles = (dir) => {
                        const files = fs.readdirSync(dir);
                        files.forEach((file) => {
                            const absoluteFilePath = path.join(dir, file);
                            const relativeFilePath = path.relative(
                                publicDir,
                                absoluteFilePath,
                            ); // 获取相对 public 的路径
                            const stats = fs.statSync(absoluteFilePath);
                            const needProcess =
                                !isWatch &&
                                stats.isFile() &&
                                compressibleFileTypes.test(file);

                            if (stats.isDirectory()) {
                                processPublicFiles(absoluteFilePath); // 递归处理子目录
                            } else {
                                // 生成文件内容的哈希值
                                const fileContent =
                                    fs.readFileSync(absoluteFilePath);
                                const hash = crypto
                                    .createHash("md5")
                                    .update(fileContent)
                                    .digest("hex")
                                    .slice(0, 8);

                                // 原始路径变成带哈希的路径
                                const ext = path.extname(file);
                                const baseName = path.basename(file, ext);

                                let distPath = path.dirname(relativeFilePath);
                                distPath =
                                    distPath === "."
                                        ? ""
                                        : path.join(distPath, "/");

                                const outputPath = needProcess
                                    ? `${distPath}${baseName}-${hash}${ext}`
                                    : `${distPath}${baseName}${ext}`;

                                const absoluteOutputPath = path.join(
                                    outputDir,
                                    outputPath,
                                );

                                // 创建目标目录并复制文件
                                fs.mkdirSync(path.dirname(absoluteOutputPath), {
                                    recursive: true,
                                });
                                fs.copyFileSync(
                                    absoluteFilePath,
                                    absoluteOutputPath,
                                );

                                if (needProcess) {
                                    fs.unlinkSync(
                                        path.join(outDir, relativeFilePath),
                                    );
                                    console.log(
                                        `Compressing: ${absoluteOutputPath}`,
                                    );
                                    compressFile(
                                        absoluteOutputPath,
                                        "gzip",
                                        "gz",
                                    );
                                    compressFile(
                                        absoluteOutputPath,
                                        "brotli",
                                        "br",
                                    );
                                }

                                // 更新 mixManifest (使用 `/` 作为路径分隔符以防止跨平台的问题)
                                mixManifest[
                                    `/${relativeFilePath.replace(/\\/g, "/")}`
                                ] = `/${outputPath.replace(/\\/g, "/")}`;
                            }
                        });
                    };

                    processPublicFiles(publicDir);

                    // 将 mixManifest 写入 mix-manifest.json
                    const manifestPath = path.join(
                        outputDir,
                        "mix-manifest.json",
                    );
                    fs.writeFileSync(
                        manifestPath,
                        JSON.stringify(mixManifest, null, 2),
                    );
                    console.log("mix-manifest.json generated:", mixManifest);
                },
            },
            {
                name: "virtual-mix-manifest",
                enforce: "post",
                // 定义一个虚拟模块内容，生产模式下，返回 mixManifest 的内容到 app.js
                resolveId(id) {
                    if (id === "virtual:mix-manifest") return id; // 虚拟模块 ID
                },
                load(id) {
                    if (id === "virtual:mix-manifest") {
                        const mixManifestPath = path.resolve(
                            __dirname,
                            "dist/mix-manifest.json",
                        ); // 替换成你的 mix-manifest.json 路径

                        if (fs.existsSync(mixManifestPath)) {
                            const mixManifestContent = fs.readFileSync(
                                mixManifestPath,
                                "utf-8",
                            );
                            return `export default ${mixManifestContent};`;
                        } else {
                            return "export default {};";
                        }
                    }
                },
            },
        ],
    };
});
