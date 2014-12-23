/* To avoid CSS expressions while still supporting IE 7 and IE 6, use this script */
/* The script tag referencing this file must be placed before the ending body tag. */

/* Use conditional comments in order to target IE 7 and older:
	<!--[if lt IE 8]><!-->
	<script src="ie7/ie7.js"></script>
	<!--<![endif]-->
*/

(function() {
	function addIcon(el, entity) {
		var html = el.innerHTML;
		el.innerHTML = '<span style="font-family: \'courseplay\'">' + entity + '</span>' + html;
	}
	var icons = {
		'icon-cloud-download': '&#xe9c2;',
		'icon-github4': '&#xeab4;',
		'icon-english': '&#xe64b;',
		'icon-german': '&#xe64c;',
		'icon-edit': '&#xe647;',
		'icon-fix': '&#xe648;',
		'icon-wiki': '&#xe646;',
		'icon-mode1block': '&#xe62a;',
		'icon-mode2block': '&#xe62b;',
		'icon-mode3block': '&#xe62c;',
		'icon-mode4block': '&#xe62d;',
		'icon-mode5block': '&#xe62e;',
		'icon-mode6block': '&#xe62f;',
		'icon-mode7block': '&#xe630;',
		'icon-mode8block': '&#xe631;',
		'icon-mode9block': '&#xe632;',
		'icon-mode1single': '&#xe633;',
		'icon-mode2single': '&#xe634;',
		'icon-mode3single': '&#xe635;',
		'icon-mode4single': '&#xe636;',
		'icon-mode5single': '&#xe637;',
		'icon-mode6single': '&#xe638;',
		'icon-mode7single': '&#xe639;',
		'icon-mode8single': '&#xe63a;',
		'icon-mode9single': '&#xe63b;',
		'icon-page0': '&#xe63c;',
		'icon-page1': '&#xe63d;',
		'icon-page2': '&#xe63e;',
		'icon-page3': '&#xe63f;',
		'icon-page4': '&#xe640;',
		'icon-page5': '&#xe641;',
		'icon-page6': '&#xe642;',
		'icon-page7': '&#xe643;',
		'icon-page8': '&#xe644;',
		'icon-page9': '&#xe645;',
		'icon-headlandClockwise2': '&#xe649;',
		'icon-headlandCounterClockwise2': '&#xe64a;',
		'icon-headlandClockwise': '&#xe628;',
		'icon-headlandCounterClockwise': '&#xe629;',
		'icon-headlandAfter': '&#xe61a;',
		'icon-headlandBefore': '&#xe61b;',
		'icon-recordingDeleteWaypoint': '&#xe603;',
		'icon-recordingPause': '&#xe604;',
		'icon-recordingPlay': '&#xe605;',
		'icon-recordingReverse': '&#xe606;',
		'icon-recordingStop': '&#xe607;',
		'icon-recordingTurn': '&#xe608;',
		'icon-calculator': '&#xe609;',
		'icon-arrowDown': '&#xe60a;',
		'icon-arrowLeft': '&#xe60b;',
		'icon-arrowRight': '&#xe60c;',
		'icon-arrowUp': '&#xe60d;',
		'icon-cancel': '&#xe60e;',
		'icon-clearCourse': '&#xe60f;',
		'icon-close': '&#xe610;',
		'icon-copy': '&#xe611;',
		'icon-crossSign': '&#xe612;',
		'icon-delete': '&#xe613;',
		'icon-eye': '&#xe614;',
		'icon-courseAppend': '&#xe615;',
		'icon-courseMoveToFolder': '&#xe616;',
		'icon-courseMoveToFolder2': '&#xe617;',
		'icon-newFolder': '&#xe618;',
		'icon-loadMergeCourse': '&#xe619;',
		'icon-infoSign': '&#xe61d;',
		'icon-minus': '&#xe61e;',
		'icon-plus': '&#xe61f;',
		'icon-save': '&#xe620;',
		'icon-search': '&#xe621;',
		'icon-waitPointSign': '&#xe622;',
		'icon-waypointSign': '&#xe623;',
		'icon-shovelLoading': '&#xe624;',
		'icon-shovelPreUnloading': '&#xe625;',
		'icon-shovelTransport': '&#xe626;',
		'icon-shovelUnloading': '&#xe627;',
		'icon-faq': '&#xe600;',
		'icon-installation': '&#xe601;',
		'icon-changelog': '&#xe602;',
		'icon-cog': '&#xf013;',
		'icon-authors': '&#xe61c;',
		'0': 0
		},
		els = document.getElementsByTagName('*'),
		i, c, el;
	for (i = 0; ; i += 1) {
		el = els[i];
		if(!el) {
			break;
		}
		c = el.className;
		c = c.match(/icon-[^\s'"]+/);
		if (c && icons[c[0]]) {
			addIcon(el, icons[c[0]]);
		}
	}
}());
