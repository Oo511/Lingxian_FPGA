(() => {
  const video = document.querySelector('#demo-video');
  const chapters = [...document.querySelectorAll('[data-time]')];
  const notice = document.querySelector('#video-notice');
  let pendingTime = null;

  function playAt(seconds) {
    notice.hidden = true;
    pendingTime = seconds;
    if (video.readyState >= 1) {
      video.currentTime = seconds;
      pendingTime = null;
    } else {
      video.load();
    }
    const playing = video.play();
    if (playing) playing.catch(() => { /* Native controls remain available. */ });
  }

  video.addEventListener('loadedmetadata', () => {
    if (pendingTime !== null) {
      video.currentTime = pendingTime;
      pendingTime = null;
    }
  });

  chapters.forEach(button => {
    button.addEventListener('click', () => playAt(Number(button.dataset.time)));
  });

  document.querySelectorAll('[data-jump]').forEach(link => {
    link.addEventListener('click', () => playAt(Number(link.dataset.jump)));
  });

  video.addEventListener('timeupdate', () => {
    const active = chapters.filter(button => Number(button.dataset.time) <= video.currentTime).pop();
    chapters.forEach(button => {
      if (button === active) button.setAttribute('aria-current', 'true');
      else button.removeAttribute('aria-current');
    });
  });

  const showVideoError = () => { notice.hidden = false; };
  video.addEventListener('error', showVideoError);
  video.querySelector('source').addEventListener('error', showVideoError);
})();
