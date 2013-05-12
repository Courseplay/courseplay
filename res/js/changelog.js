;(function ($) { $(document).ready(function () {
$('body').removeClass('no-js').addClass('js');

CP = {};

CP.animationTime = 250;
CP.el = {
	secChangelog: $('#changelog'),
	changelogVersions: $('div.changelogVersion')
};
CP.el.changelogTitles = CP.el.changelogVersions.find('h3')
CP.el.changelogContent = CP.el.changelogVersions.find('.changelogContent');
CP.el.changelogVersions.filter(':first').find('.changelogContent').addClass('open');
CP.el.changelogVersions.not(':first').find('.changelogContent').addClass('closed');

CP.el.changelogTitles.on('click', function(evt) {
	var t = $(this),
		thisContent = t.next('.changelogContent'),
		isOpen = thisContent.hasClass('open');

	CP.el.changelogContent.removeClass('open').addClass('closed');
	if (!isOpen) {
		thisContent.removeClass('closed').addClass('open');
		scrollTo('#' + t.parents('.changelogVersion').attr('id'));
	};
});

function scrollTo(targetId) {
	$('html, body').animate({
		scrollTop: $(targetId).offset().top
	}, CP.animationTime);
} //END scrollTo()	



$.fn.slideFadeToggle = function(speed, easing, callback) {
	return this.animate({opacity: 'toggle', height: 'toggle'}, speed, easing, callback);
};

}); })(jQuery); //END document.ready
