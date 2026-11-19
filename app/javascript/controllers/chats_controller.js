import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("chats controller connected")

    // For right/left swipe on message
    this.touchStartX = 0;
    this.touchStartY = 0;
    this.touchEndX = 0;
    this.touchEndY = 0;
    this.originalX = this.element.offsetLeft;
    this.originalY = this.element.offsetTop;

    document.addEventListener('click', function(e){
      console.log(e.target.getAttribute("id"))
      if (document.getElementById('chat-modal').contains(e.target)){
        // Clicked in box
      } else if(e.target.getAttribute("id") != "good-link"){
        // Clicked outside the box
        let modal = document.getElementById("chat-modal")
        modal.classList.add("hidden")
      }

      // The admin panel follows the same rule: any touch outside it, other
      // than on its own trigger, puts it away again.
      const adminPanel = document.getElementById("admin-panel")
      if (adminPanel && !adminPanel.contains(e.target)) {
        const trigger = e.target.closest ? e.target.closest("#queries-link, #good-link") : null
        if (!trigger) adminPanel.classList.add("hidden")
      }
    });

    this.interval = setInterval(() => {
        this.loadMessages();
    }, 3000);
  }

  disconnect() {
      // Clear the interval when the controller is disconnected
      clearInterval(this.interval);
  }

  // Reveals the admin panel. Hidden by default like everything else here.
  toggleAdmin(){
    let panel = document.getElementById("admin-panel")
    if (!panel) return
    panel.classList.toggle("hidden")
    if (!panel.classList.contains("hidden")) {
      panel.scrollIntoView({ behavior: "smooth", block: "start" })
    }
  }

  // Switch conversation without reloading the page.
  //
  // The session is the single source of truth for who the admin is talking
  // to: sending, polling and Pusher all read it server side. So we ask the
  // server to switch FIRST, and only redraw once it confirms. Doing it the
  // other way round would leave a window where the screen shows one person
  // and a sent message goes to another.
  switchUser(event){
    event.preventDefault()

    const link   = event.currentTarget
    const userId = link.getAttribute("data-user-id")
    if (!userId) return

    if (this.switching) return
    this.switching = true
    link.style.opacity = "0.5"

    fetch(link.href, {
      headers: { "Accept": "application/json", "X-Requested-With": "XMLHttpRequest" },
      credentials: "same-origin"
    })
      .then((response) => {
        if (!response.ok) throw new Error("switch failed: " + response.status)
        return response.json()
      })
      .then((data) => {
        if (!data.ok) throw new Error("server did not switch")

        // Keep the Pusher handler pointed at the conversation now on screen.
        window.selectedUserId = data.selected_user_id

        this.markActiveChip(userId)
        this.clearBadge(link)
        this.clearComposer()
        this.showSwitchLoader(data.username)
        this.reloadConversation()
      })
      .catch((error) => {
        // Never leave the screen showing one person while the server thinks
        // another - fall back to a full load, which cannot disagree.
        console.error(error)
        window.location.href = link.href
      })
      .finally(() => {
        this.switching = false
        link.style.opacity = ""
      })
  }

  showSwitchLoader(username){
    const loader = document.getElementById("switch-loader")
    if (!loader) return

    const name = document.getElementById("switch-loader-name")
    if (name && username) name.textContent = username
    loader.classList.remove("hidden")

    // The frame tells us when the conversation has actually arrived.
    const frame = document.getElementById("messages_list")
    if (!frame) return

    const done = () => {
      loader.classList.add("hidden")
      frame.removeEventListener("turbo:frame-load", done)
    }
    frame.addEventListener("turbo:frame-load", done)

    // Never leave a spinner running if the frame event does not arrive.
    setTimeout(done, 8000)
  }

  markActiveChip(userId){
    document.querySelectorAll("a[data-user-id]").forEach((chip) => {
      const on = chip.getAttribute("data-user-id") === String(userId)
      chip.classList.toggle("bg-gray-900", on)
      chip.classList.toggle("text-white", on)
      chip.classList.toggle("bg-white", !on)
      chip.classList.toggle("text-gray-900", !on)
      chip.classList.toggle("border", !on)
      chip.classList.toggle("border-gray-200", !on)
      chip.classList.toggle("[@media(hover:hover)]:hover:bg-gray-50", !on)

      const avatar = chip.querySelector("span")
      if (avatar) {
        avatar.classList.toggle("bg-white/20", on)
        avatar.classList.toggle("text-white", on)
        avatar.classList.toggle("bg-blue-100", !on)
        avatar.classList.toggle("text-blue-700", !on)
      }
    })
  }

  clearBadge(link){
    const badge = link.querySelector(".unseen-badge")
    if (badge) badge.remove()
  }

  // A half typed message belongs to the conversation it was typed in.
  clearComposer(){
    const box = document.getElementById("text-message")
    if (box) box.value = ""
    const replyId = document.getElementById("reply-to-id")
    if (replyId) replyId.value = ""
    const replyBox = document.getElementById("reply-msg-box")
    if (replyBox) replyBox.classList.add("hidden")
  }

  reloadConversation(){
    const msgFrame = document.getElementById("messages_list")
    if (!msgFrame) return
    msgFrame.src = "/dash"
    msgFrame.reload()
  }

  openModal(){
    let modal = document.getElementById("chat-modal")
    if(modal.classList.contains("hidden")){
      modal.classList.remove("hidden")
      this.checkFunction()
    }else{
      modal.classList.add("hidden")
    }
  }

  closeModal(){
    let modal = document.getElementById("chat-modal")
    modal.classList.add("hidden")
  }

  sendMessage(){
    // While a message is being edited, the same button saves it.
    if (this.editingId && this.saveEdit()) return

    const msgBox = document.getElementById("text-message")
    const msgValue = msgBox.value

    let msgBtn = document.getElementById('send-message')
    let msgSending = document.getElementById('sending-message')

    msgBtn.classList.add("hidden")
    msgSending.classList.remove("hidden")
  
    if(msgValue.trim() != ""){
      const encryptedMsg = btoa(unescape(encodeURIComponent(msgValue)));
      fetch(`/dash/msg`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        },
        body: JSON.stringify({ 'encrypted_data': encryptedMsg, reply_to_id: document.getElementById("reply-to-id").value.trim() }),
        dataType: "json",
        credentials: 'same-origin'
      }).then(response => response.json())
        .then(result => {
          msgBtn.classList.remove("hidden")
          msgSending.classList.add("hidden")
          msgBox.value = ""
          this.removeReply()
          if(result.code == 200){
            this.checkFunction()
          }
      }).catch(error => {
        console.error('Error fetching data:', error);
       msgBtn.classList.remove("hidden")
       msgSending.classList.add("hidden")
      });
    } else {
      msgBtn.classList.remove("hidden")
      msgSending.classList.add("hidden")
    }
  }

  scrollMsgsBtm(){
    // var elem = document.getElementById('message-container');
    // elem.scrollTop = elem.scrollHeight;

    const msgBox = document.getElementById("text-message")
    msgBox.focus()
  }

  checkFunction() {
    let modal = document.getElementById("chat-modal")
    // Check if the div does not have the hidden class
    if (!modal.classList.contains('hidden')) {
        // Execute your desired functionality here
        // Add your function call or logic here
        const msgFrame = document.getElementById("messages_list");
        msgFrame.src = '/dash';
        msgFrame.reload();
        this.scrollMsgsBtm()
    }
  }

  loadMessages(){
    let indicator = document.getElementById("new-message-indicator")
    if(indicator.value == "true") {
      indicator.value = "false"
      const msgFrame = document.getElementById("messages_list");
      msgFrame.src = '/dash';
      msgFrame.reload();
      this.scrollMsgsBtm()
    }
  }

  messageTimestamp(){
    const msgTimeDivId = event.currentTarget.getAttribute("attr-msg")
    const msgTimeDiv = document.getElementById(msgTimeDivId)
    if (msgTimeDiv.classList.contains("hidden")) {
      msgTimeDiv.classList.remove("hidden")
    } else {
      msgTimeDiv.classList.add("hidden")
    }
  }

// ---------------------------------------------------------------- replying
// Swipe a bubble to the right to reply, the way every chat app does. The
// threshold is deliberately generous so a scroll is never mistaken for it.
swipeStart(event){
  const touch = event.touches && event.touches[0]
  if (!touch) return
  this.swipeRow = event.currentTarget
  this.swipeX = touch.clientX
  this.swipeY = touch.clientY
  this.swiping = false
}

swipeMove(event){
  if (!this.swipeRow) return
  const touch = event.touches && event.touches[0]
  if (!touch) return

  const dx = touch.clientX - this.swipeX
  const dy = touch.clientY - this.swipeY

  // Vertical movement means the list is being scrolled - leave it alone.
  if (Math.abs(dy) > Math.abs(dx)) { this.cancelSwipe(); return }
  if (dx <= 0) return

  this.swiping = true
  const shift = Math.min(dx, 72)
  this.swipeRow.style.transform = "translateX(" + shift + "px)"

  const hint = this.swipeRow.querySelector("[data-swipe-hint]")
  if (hint) hint.style.opacity = String(Math.min(shift / 60, 1))

  if (dx > 10 && event.cancelable) event.preventDefault()
}

swipeEnd(){
  if (!this.swipeRow) return
  const row = this.swipeRow
  const shift = parseFloat((row.style.transform.match(/-?\d+(\.\d+)?/) || [0])[0])

  row.style.transition = "transform 150ms ease"
  row.style.transform = "translateX(0)"
  setTimeout(() => { row.style.transition = "" }, 180)

  const hint = row.querySelector("[data-swipe-hint]")
  if (hint) hint.style.opacity = "0"

  if (this.swiping && shift >= 50) this.replyTo(row.getAttribute("data-msg-id"))
  this.cancelSwipe()
}

cancelSwipe(){
  if (this.swipeRow) {
    this.swipeRow.style.transform = ""
    const hint = this.swipeRow.querySelector("[data-swipe-hint]")
    if (hint) hint.style.opacity = "0"
  }
  this.swipeRow = null
  this.swiping = false
}

replyTo(messageId){
  if (!messageId) return
  const content = document.getElementById("msg-content-" + messageId)
  const text = content ? content.innerText.trim() : ""

  document.getElementById("reply-to-id").value = messageId
  document.getElementById("reply-to").innerText =
    "Reply to: " + (text.length > 60 ? text.substring(0, 60) + "..." : text)
  document.getElementById("reply-msg-box").classList.remove("hidden")
  this.scrollMsgsBtm()
}

// ---------------------------------------------------------------- editing
startEdit(event){
  event.preventDefault()
  event.stopPropagation()

  const id = event.currentTarget.getAttribute("attr-msg-id")
  const content = document.getElementById("msg-content-" + id)
  if (!content) return

  const box = document.getElementById("text-message")
  box.value = content.innerText.trim()
  box.focus()

  this.editingId = id
  this.showEditBanner(box.value)
}

showEditBanner(original){
  let banner = document.getElementById("edit-banner")
  if (!banner) return
  const label = document.getElementById("edit-banner-text")
  if (label) {
    label.textContent = original.length > 50 ? original.substring(0, 50) + "..." : original
  }
  banner.classList.remove("hidden")
}

cancelEdit(){
  this.editingId = null
  const banner = document.getElementById("edit-banner")
  if (banner) banner.classList.add("hidden")
  const box = document.getElementById("text-message")
  if (box) box.value = ""
}

saveEdit(){
  const box = document.getElementById("text-message")
  const text = box.value.trim()
  const id = this.editingId
  if (!id) return false

  if (text === "") {
    alert("A message cannot be left empty.")
    return true
  }

  const token = document.querySelector('meta[name="csrf-token"]')

  fetch("/dash/msg/" + id, {
    method: "PATCH",
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "X-CSRF-Token": token ? token.getAttribute("content") : ""
    },
    body: JSON.stringify({ encrypted_data: btoa(unescape(encodeURIComponent(text))) }),
    credentials: "same-origin"
  })
    .then((r) => r.json())
    .then((result) => {
      if (!result.ok) { alert(result.error || "The message could not be changed."); return }
      this.cancelEdit()
      this.reloadConversation()
    })
    .catch(() => alert("The message could not be changed."))

  return true
}

  addReply(){
    const replyMsgId= event.currentTarget.getAttribute("attr-msg-id")
    const replyMsgContent = document.getElementById('msg-content-'+replyMsgId).innerText
    document.getElementById("reply-to-id").value = replyMsgId
    document.getElementById("reply-to").innerText = "Reply to: " +  (replyMsgContent.length > 60 ? replyMsgContent.substring(0,60)+"..." : replyMsgContent)
    document.getElementById('reply-msg-box').classList.remove("hidden")
    this.scrollMsgsBtm()
  }

  removeReply(){
    document.getElementById('reply-msg-box').classList.add("hidden")
    document.getElementById('reply-to-id').value = ""
    document.getElementById('reply-to').value = ""
    this.scrollMsgsBtm()
  }

clearImg(){
  const input = document.getElementById("file-input")
  const img   = document.getElementById("selected-image")
  const video = document.getElementById("selected-video")

  if (img && img.src.startsWith("blob:")) URL.revokeObjectURL(img.src)
  if (video && video.src.startsWith("blob:")) URL.revokeObjectURL(video.src)

    this.pendingFile = null
  if (input) input.value = ""
  if (img) { img.removeAttribute("src"); img.classList.add("hidden") }
  if (video) { video.removeAttribute("src"); video.classList.add("hidden") }

  document.getElementById("attach-card").classList.add("hidden")
  document.getElementById("attach-button").classList.remove("hidden")
  this.resetUploadState()
}

// Picking a file: show what it is and how big before anything is sent, and
// refuse one that is already over the limit rather than uploading it first.
filePreview(event) {
  const input = event.target
  const file  = input.files && input.files[0]
  if (!file) return

  const form     = document.getElementById("upload-form")
  const maxImage = parseInt(form.dataset.maxImage || "0", 10)
  const maxVideo = parseInt(form.dataset.maxVideo || "0", 10)

  const isImage = file.type.startsWith("image/")
  const isVideo = file.type.startsWith("video/")
  const limit   = isVideo ? maxVideo : maxImage

  this.resetUploadState()

  if (!isImage && !isVideo) {
    this.showUploadError("Only pictures and videos can be sent.")
    input.value = ""
    return
  }

  if (limit && file.size > limit) {
    this.showUploadError(
      "That file is " + this.humanSize(file.size) + ". The limit is " + this.humanSize(limit) + "."
    )
    input.value = ""
    return
  }

  const img   = document.getElementById("selected-image")
  const video = document.getElementById("selected-video")
  const icon  = document.getElementById("attach-icon")
  const url   = URL.createObjectURL(file)

  img.classList.add("hidden")
  video.classList.add("hidden")
  icon.classList.add("hidden")

  if (isImage) {
    img.src = url
    img.classList.remove("hidden")
  } else {
    video.src = url
    video.classList.remove("hidden")
  }

  document.getElementById("attach-name").textContent = file.name
  document.getElementById("attach-meta").textContent =
    (isVideo ? "Video · " : "Photo · ") + this.humanSize(file.size)

  this.pendingFile = file

  if (isImage) {
    file.arrayBuffer()
      .then((buffer) => {
        this.pendingFile = new File([buffer], file.name, { type: file.type })
      })
      .catch(() => {
        // keep the original reference; the send-time check will catch it
      })
  }

  document.getElementById("attach-card").classList.remove("hidden")
  document.getElementById("attach-button").classList.add("hidden")
}

// Upload over XHR so there is a real progress bar. A large video used to
// block the page with no feedback at all, because the form posted normally
// and the Cloudinary upload ran inside that request.
sendImage(event) {
  event.preventDefault()

  const form  = document.getElementById("upload-form")
  const input = document.getElementById("file-input")
  const file  = this.pendingFile || (input.files && input.files[0])

  if (!file) {
    this.showUploadError("Pick a photo or video first.")
    return
  }

  // An empty file means the phone released it before we could send.
  if (!file.size) {
    this.showUploadError("That photo was no longer available. Please pick it again.")
    return
  }

  const button   = document.getElementById("submit-image-btn")
  const progress = document.getElementById("upload-progress")
  const bar      = document.getElementById("upload-bar")
  const status   = document.getElementById("upload-status")

  this.hideUploadError()
  progress.classList.remove("hidden")
  button.disabled = true
  button.textContent = "Sending…"
  bar.style.width = "0%"

  const xhr = new XMLHttpRequest()
  xhr.open("POST", form.action, true)
  xhr.setRequestHeader("Accept", "application/json")
  xhr.setRequestHeader("X-Requested-With", "XMLHttpRequest")

  // Send the token from the meta tag, the way sendMessage already does.
  // The copy embedded in the form is a per-form token and was rejected
  // with "Can not verify CSRF token authenticity", so do not rely on it.
  const csrf = document.querySelector('meta[name="csrf-token"]')
  if (csrf) xhr.setRequestHeader("X-CSRF-Token", csrf.getAttribute("content"))

  xhr.upload.onprogress = (e) => {
    if (!e.lengthComputable) return
    const pct = Math.round((e.loaded / e.total) * 100)
    bar.style.width = pct + "%"
    status.textContent = pct < 100
      ? "Sending… " + pct + "% of " + this.humanSize(e.total)
      : "Finishing up on the server…"
  }

  xhr.onload = () => {
    let body = {}
    try { body = JSON.parse(xhr.responseText) } catch (err) { /* keep {} */ }

    if (xhr.status >= 200 && xhr.status < 300 && body.ok) {
      this.clearImg()
      this.reloadConversation()
    } else {
      this.showUploadError(body.error || "Upload failed. Please try again.")
      progress.classList.add("hidden")
    }

    button.disabled = false
    button.textContent = "Send"
  }

  xhr.onerror = () => {
    this.showUploadError("The connection dropped before the file finished.")
    progress.classList.add("hidden")
    button.disabled = false
    button.textContent = "Send"
  }

  // Built by hand rather than from the form, so the bytes we send are the
  // ones we read at selection time.
  const payload = new FormData()
  const token = form.querySelector('input[name="authenticity_token"]')
  if (token) payload.append("authenticity_token", token.value)
  payload.append("image", file, file.name)

  xhr.send(payload)
}

humanSize(bytes) {
  if (!bytes) return "0 B"
  const units = ["B", "KB", "MB", "GB"]
  let n = bytes, i = 0
  while (n >= 1024 && i < units.length - 1) { n = n / 1024; i++ }
  return (i === 0 ? n : n.toFixed(1)) + " " + units[i]
}

showUploadError(message) {
  const box = document.getElementById("upload-error")
  if (!box) return
  box.textContent = message
  box.classList.remove("hidden")
}

hideUploadError() {
  const box = document.getElementById("upload-error")
  if (box) box.classList.add("hidden")
}

resetUploadState() {
  this.hideUploadError()
  const progress = document.getElementById("upload-progress")
  if (progress) progress.classList.add("hidden")
  const bar = document.getElementById("upload-bar")
  if (bar) bar.style.width = "0%"
}

  openImageModal(){
    const modalId = event.currentTarget.getAttribute("data-modal-target")
    console.log(modalId)
    document.getElementById(modalId).classList.remove("hidden")
  }

  closeImageModal(){
    const modalId = event.currentTarget.getAttribute("attr-modal")
    const modalContains = event.currentTarget.getAttribute("attr-contains")
    if(modalContains != "video"){
      document.getElementById(modalId).classList.add("hidden")
    }
  }
}
