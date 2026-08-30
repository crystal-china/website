const MAX_FILE_SIZE = 5 * 1024 * 1024;

function pasteImage(textarea) {
    textarea.addEventListener("paste", async (event) => {
        await handlePasteEvent(event, textarea);
    });
}

// 粘贴事件处理函数
async function handlePasteEvent(event, textarea) {
    const clipboardData = event.clipboardData;
    const items = clipboardData.items;

    for (let i = 0; i < items.length; i++) {
        const item = items[i];

        // 检查是否为图片数据
        if (item.type.indexOf("image") === 0) {
            event.preventDefault(); // 阻止默认粘贴行为

            const file = item.getAsFile();

            // 检查是否超出文件大小限制
            if (file.size > MAX_FILE_SIZE) {
                alert(
                    `文件大小超过限制！最大支持上传 ${MAX_FILE_SIZE / (1024 * 1024)}MB 的图片。`,
                );
                return; // 阻止后续上传逻辑
            }

            // 在光标位置插入上传占位符
            const placeholderId = insertUploadingPlaceholder(
                textarea,
                file.name, // 默认 image.png
            );

            try {
                // 上传图片
                const imageUrl = await uploadImage(file);

                // 替换占位符为 Markdown 图片标签
                replacePlaceholderWithMarkdown(
                    textarea,
                    placeholderId,
                    imageUrl,
                );
            } catch (error) {
                console.error("图片上传失败", error);

                // 替换占位符为错误消息
                replacePlaceholderWithError(
                    textarea,
                    placeholderId,
                    `上传失败：${error.message}`,
                );
            }
        }
    }
}

// 辅助函数：插入上传占位符
function insertUploadingPlaceholder(textarea, filename) {
    // 生成唯一占位符 ID（基于时间戳，避免冲突）
    const placeholderId = `Uploading_${Date.now()}`;

    // 创建占位符文本，例如： <!-- Uploading "image.png" -->
    const placeholderText = `<!-- Uploading "${filename}" (${placeholderId}) -->`;
    // <!-- Uploading "image.png"... -->

    // 获取光标位置
    const start = textarea.selectionStart;
    const end = textarea.selectionEnd;

    // 获取当前 textarea 的值
    const value = textarea.value;

    // 在光标所在位置插入内容
    const before = value.substring(0, start); // 光标前的内容
    const after = value.substring(end); // 光标后的内容
    textarea.value = before + placeholderText + after;

    // 调整光标位置到插入内容之后
    const newCursorPosition = start + placeholderText.length;
    textarea.setSelectionRange(newCursorPosition, newCursorPosition);
    textarea.focus();

    return placeholderId; // 返回占位符 ID 以便后续替换
}

// 辅助函数：替换占位符为 Markdown 图片标签
function replacePlaceholderWithMarkdown(textarea, placeholderId, imageUrl) {
    const placeholderRegex = new RegExp(
        `<!-- Uploading .*?\\(${placeholderId}\\) -->`,
        "g",
    );

    // 替换占位符为 Markdown 图片标签
    textarea.value = textarea.value.replace(
        placeholderRegex,
        `![image](${imageUrl})`,
    );
}

// 辅助函数：替换占位符为错误消息
function replacePlaceholderWithError(textarea, placeholderId, errorMessage) {
    const placeholderRegex = new RegExp(
        `<!-- Uploading .*?\\(${placeholderId}\\) -->`,
        "g",
    );

    // 替换占位符为错误消息
    textarea.value = textarea.value.replace(
        placeholderRegex,
        `<!-- ${errorMessage} -->`,
    );
}

// // 模拟一个上传过程，你需要替换为实际上传代码，发送 file 到服务端的接口，并返回图片 URL
// async function uploadImage(file) {
//     return new Promise((resolve) => {
//         setTimeout(() => {
//             // 模拟生成的图片 URL
//             resolve("https://example.com/uploaded-image.png");
//         }, 5000);
//     });
// }

async function uploadImage(file) {
    const formData = new FormData();
    formData.append("source", file);

    const response = await fetch("/api/upload", {
        method: "POST",
        headers: {
            "X-CSRF-TOKEN": document.querySelector(
                'meta[name="csrf-token"]',
            ).content,
        },
        body: formData,
    });

    const data = await response.json();

    if (data.status === "success") {
        return data.image_url; // 返回图片 URL
    } else {
        throw new Error(data.message || "上传失败");
    }
}

// const items = (event.clipboardData || event.originalEvent.clipboardData).items;

export default pasteImage;
