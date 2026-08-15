const copyButtonLabel = "📄";

function copyCodeButton(blockElt) {
    // only add button if browser supports Clipboard API
    if (navigator.clipboard) {
        blockElt.style.position = "relative";

        let button = blockElt.querySelector("button.copyBtn");

        if (button === null) {
            button = document.createElement("button");
            button.className = "copyBtn";
            button.setAttribute(
                "style",
                "position: absolute; top: 0.75rem; right: 0.75rem; z-index: 1; padding: 0; border: 0; line-height: 1; background: transparent; opacity: 0.45; transition: opacity 150ms ease; cursor: pointer;",
            );
            button.innerText = copyButtonLabel;
        }

        button.addEventListener("mouseenter", () => {
            button.style.opacity = "1";
        });

        button.addEventListener("mouseleave", () => {
            button.style.opacity = "0.45";
        });

        button.addEventListener("focus", () => {
            button.style.opacity = "1";
        });

        button.addEventListener("blur", () => {
            button.style.opacity = "0.45";
        });

        button.addEventListener("click", async () => {
            await copyCode(blockElt, button);
        });

        blockElt.prepend(button);
    }
}

async function copyCode(blockElt, button) {
    let code = blockElt.querySelector("code");
    let lineNumbers = code.querySelectorAll('span[style="user-select: none;"]');
    lineNumbers.forEach((span) => {
        span.setAttribute("style", "user-select: none; display: none;");
    });
    let text = code.innerText;
    lineNumbers.forEach((span) => {
        span.setAttribute("style", "user-select: none;");
    });

    await navigator.clipboard.writeText(text);

    button.innerText = "copied";

    setTimeout(() => {
        button.innerText = copyButtonLabel;
    }, 1500);
}

export default copyCodeButton;
