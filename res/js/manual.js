;(function ($) { $(document).ready(function () {
$('body').removeClass('no-js').addClass('js');

// if hash isn't used in url, default to "#intro"
var hash = window.location.hash;
if (!hash || hash == '' || hash == 'undefined') {
	if (history.pushState) {
		history.pushState(null, null, '#intro');
		// console.log('pushState "#intro"')
	} else {
		location.hash = '#intro';
		// console.log('set location.hash to "#intro"')
	}
};

}); })(jQuery); //END document.ready
