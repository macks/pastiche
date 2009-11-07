$(function() {
  $('.flash-message-box').each(function() {
    var box = $(this);
    var button = $(document.createElement('div'));
    box.append(button);
    button.addClass('close-button').append('&times;').attr('title', 'close').click(function() { box.hide(); });
  });
  $('.to-be-invisible').addClass('invisible');
  $('input.placeholder').each(function() {
    if (this.value) { $(this).removeClass('placeholder'); }
  }).focus(function() {
    $(this).removeClass('placeholder');
  }).blur(function() {
    if (!this.value) { $(this).addClass('placeholder'); }
  });
  $('ul.snippets .snippet-comment a').click(function() {
    var div = $(this).parent();
    div.empty().append(div.siblings('.snippet-body').attr('title'));
    return false;
  });
});
