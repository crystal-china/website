const copyButtonLabel = "📄";

function copyCodeButton(blockElt) {
    // only add button if browser supports Clipboard API
    if (navigator.clipboard) {
        let button = blockElt.querySelector("button.copyBtn");

        if (button === null) {
            button = document.createElement("button");
            button.className = "copyBtn";
            button.setAttribute(
                "style",
                "float: right; padding: 0; border: 0; line-height: 1; background: transparent;",
            );
            button.innerText = copyButtonLabel;
        }

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
