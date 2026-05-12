<template>
  <div class="model-chat">
    <p class="subtitle">与模型实时对话</p>
    <div class="iframe-wrap">
      <iframe
        src="http://localhost/chatbot/LIjDpLe4dadZWoZK"
        title="LLM Chatbot"
        frameborder="0"
        allow="microphone"
      ></iframe>
    </div>
    <div class="hint">
      如果无法加载，请确认本机聊天服务可访问：
      <a href="http://localhost/chatbot/LIjDpLe4dadZWoZK" target="_blank" rel="noopener">http://localhost/chatbot/LIjDpLe4dadZWoZK</a>
    </div>
  </div>
</template>

<style scoped>
.model-chat {
  display: grid;
  gap: 10px;
}

.subtitle {
  color: var(--text-muted);
}

.iframe-wrap {
  border: 1px solid var(--line);
  border-radius: 8px;
  overflow: hidden;
  background: #fff;
}

.iframe-wrap iframe {
  width: 100%;
  min-height: 700px;
  display: block;
}

.hint {
  color: var(--text-muted);
  font-size: 13px;
}

.hint a {
  color: var(--brand-2);
  text-decoration: underline;
}
</style>
