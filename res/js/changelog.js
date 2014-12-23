;(function ($) { $(document).ready(function () {
$('body').removeClass('no-js').addClass('js');

CP = {};

CP.animationTime = 250;
CP.el = {
	secChangelog: $('#changelog'),
	singleChangelogs: $('.singleChangelog')
};
CP.el.changelogTitles = CP.el.singleChangelogs.find('h3');
CP.el.changelogsContent = CP.el.singleChangelogs.find('.changelogContent');
CP.el.singleChangelogs.filter(':first').find('.changelogContent').addClass('open');
CP.el.singleChangelogs.not(':first').find('.changelogContent').addClass('closed');

CP.el.changelogTitles.on('click', function(evt) {
	var t = $(this),
		thisContent = t.parent().find('.changelogContent'),
		isOpen = thisContent.hasClass('open');

	CP.el.changelogsContent.removeClass('open').addClass('closed');
	if (!isOpen) {
		thisContent.removeClass('closed').addClass('open');
		scrollTo(t);
	};
});

function scrollTo(el) {
	$('html, body').animate({
		scrollTop: el.offset().top
	}, CP.animationTime);
} //END scrollTo()	



$.fn.slideFadeToggle = function(speed, easing, callback) {
	return this.animate({opacity: 'toggle', height: 'toggle'}, speed, easing, callback);
};

}); })(jQuery); //END document.ready
