;(function ($) { $(document).ready(function () {
$('body').removeClass('no-js').addClass('js');

// add hover class to links and listItems when touched (e.g. on phone, tablet etc.)
$('#navSidebar').find('ul').find('a, li').bind('touchstart touchend', function(e) {
	e.preventDefault();
	$(this).toggleClass('hover');
});

}); })(jQuery); //END document.ready
