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
  $('ul.snippets .snippet-description a').click(function() {
    var div = $(this).parent();
    div.empty().append(div.siblings('.snippet-body').attr('title'));
    return false;
  });
  $('.snippet-body').each(function() {
    var body = $(this);
    var hash = location.hash;
    if (!hash || !RegExp('^#L(\\d+)(?:-(\\d+))?$').exec(hash))
      return;
    var line_start = Number(RegExp.$1), line_end = Number(RegExp.$2);
    var highlighten = function(n) {
      body.find('.L' + n).addClass('highlight-line');
    };
    if (line_start && line_end) {
      $('html,body').animate({scrollTop: $('a[name=L' + line_start + ']').offset().top}, 1);
      for (var n = line_start; n <= line_end; n++)
        highlighten(n);
    } else {
      highlighten(line_start);
    }
  });
});
