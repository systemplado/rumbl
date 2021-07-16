import Player from './player'

let Video = {

  init(socket, element){ if(!element){ return }
    let playerId = element.getAttribute('data-player-id')
    let videoId  = element.getAttribute('data-id')
    socket.connect()
    Player.init(element.id, playerId, () => { 
      this.onReady(videoId, socket)
    })
  },

  onReady(videoId, socket){
    let msgContainer = document.getElementById('msg-container')
    let msgInput = document.getElementById('msg-input')
    let postButton = document.getElementById('msg-submit')
    let lastSeenId = 0
    let vidChannel = socket.channel('videos:' + videoId, () => {
      return {last_seen_id: lastSeenId}
    })

    postButton.addEventListener('click', e => {
      let payload = {body: msgInput.value, at: Player.getCurrentTime()}

      vidChannel
        .push('new_annotation', payload)
        .receive('error', reason => console.log(reason) )

      msgInput.value = ''
    })

    msgContainer.addEventListener('click', e => {
      let seconds = e.target.getAttribute('data-seek')

      e.preventDefault()
      if (!seconds) return

      Player.seekTo(seconds)
    })

    vidChannel.on('new_annotation', resp => {
      lastSeenId = resp.id
      this.renderAnnotation(msgContainer, resp, true)
    })

    vidChannel.join()
    .receive('ok', ({annotations}) => {
      let ids = annotations.map(ann => ann.id)

      if (ids.length > 0) lastSeenId = Math.max(...ids)
      this.scheduleMessages(msgContainer, annotations)
    })
    .receive('error', reason => console.log('joined failed', reason) )
  },

  renderAnnotation(msgContainer, {user, body, at}, is_new = false){
    let template = document.createElement("div")
    template.innerHTML = `
      <a href="#" data-seek="${this.esc(at)}">
        [${this.formatTime(at)}]
      </a>
      <span class="new">${is_new ? ' [NEW] ' : ''}</span>
      <b>${this.esc(user.username)}</b>: ${this.esc(body)}
      `
    msgContainer.appendChild(template)
    msgContainer.scrollTop = msgContainer.scrollHeight
  },

  scheduleMessages(msgContainer, annotations){
    clearTimeout(this.scheduleTimer)

    this.schedulerTimer = setTimeout(() => {
      let ctime = Player.getCurrentTime()
      let remaining = this.renderAtTime(annotations, ctime, msgContainer)
      this.scheduleMessages(msgContainer, remaining)
    }, 1000)
  },

  renderAtTime(annotations, seconds, msgContainer){
    return annotations.filter( ann => {
      if(ann.at > seconds){
        return true
      } else {
        this.renderAnnotation(msgContainer, ann)
        return false
      }
    })
  },

  formatTime(at){
    let date = new Date(null)
    date.setSeconds(at / 1000)
    return date.toISOString().substr(14, 5)
  },

  esc(str){
    let div = document.createElement("div")
    div.appendChild(document.createTextNode(str))
    return div.innerHTML
  }
}

export default Video
