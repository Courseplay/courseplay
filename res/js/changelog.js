;(function ($) { $(document).ready(function () {

CP = {};

CP.animationTime = 200;
CP.el = {
	secChangelog: $('#changelog'),
	changelogVersions: $('div.changelogVersion'),
};
CP.el.changelogVersions.filter('.closed').find('> ul').hide();
CP.el.changelogToggle = CP.el.changelogVersions.find('.toggle').css('display', 'inline-block');
CP.el.changelogToggle.on('click', function() {
	var otherVersions = CP.el.changelogVersions.not($(this).parents('div.changelogVersion'));
	var otherToggles = CP.el.changelogToggle.not($(this));
	otherVersions.removeClass('open').addClass('closed').find('> ul').slideUp(CP.animationTime).fadeOut(CP.animationTime);
	otherToggles.each(function() {
		$(this).attr('data-icon', $(this).attr('data-icon-closed'));
	});

	$(this).parents('div.changelogVersion').find('> ul').slideDown(CP.animationTime).fadeIn(CP.animationTime);
	$(this).attr('data-icon', $(this).attr('data-icon-open'));
});



}); })(jQuery); //END document.ready
