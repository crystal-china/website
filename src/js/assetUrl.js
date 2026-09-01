function createAssetUrl(assetHost, assetBasePath) {
    let assetManifestPromise;

    function loadAssetManifest() {
        if (assetManifestPromise == null) {
            assetManifestPromise = fetch("/bun-manifest.json", {
                cache: "no-store",
            })
                .then((response) => {
                    if (!response.ok) {
                        throw new Error(
                            `Failed to load bun-manifest.json: ${response.status}`,
                        );
                    }

                    return response.json();
                })
                .catch((error) => {
                    assetManifestPromise = undefined;
                    console.warn(error);
                    return {};
                });
        }

        return assetManifestPromise;
    }

    return async function assetUrl(
        logicalPath,
        fallback = `/assets/${logicalPath}`,
    ) {
        const manifest = await loadAssetManifest();
        const manifestPath = manifest[logicalPath];
        const resolvedPath =
            manifestPath == null
                ? fallback
                : `${assetBasePath}/${manifestPath}`;

        return `${assetHost}${resolvedPath}`;
    };
}

export default createAssetUrl;
