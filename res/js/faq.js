;(function ($) { $(document).ready(function () {
$('body').removeClass('no-js').addClass('js');
/** TOGGLE **/
CP = {};

CP.animationTime = 250;
CP.el = {
	faqContent: $('.faqContent'),
	faqTitles: $('.singleFaq').find('h2')
};
CP.el.faqContent.addClass('closed');

CP.el.faqTitles.on('click', function(evt) {
	var t = $(this),
		thisFaqContent = t.next('.faqContent'),
		isOpen = thisFaqContent.hasClass('open');

	CP.el.faqContent.removeClass('open').addClass('closed');
	if (!isOpen) {
		thisFaqContent.removeClass('closed').addClass('open');
		scrollTo(t.parents('.singleFaq'));
	};
});

function scrollTo(el) {
	$('html, body').animate({
		scrollTop: el.offset().top
	}, CP.animationTime);
} //END scrollTo()


/** SYMMETRIC LANE CHANGE **/
var stage = new Kinetic.Stage({
	container: 'laneChangeStage',
	width: $('#faqOffset').width(),
	height: 400
});

var layer = new Kinetic.Layer();

var bottomLine = new Kinetic.Rect({
	x: 0,
	y: stage.getHeight() - 2,
	width: stage.getWidth(),
	height: 2,
	fill: 'rgba(240,240,240,1)',
});
layer.add(bottomLine);

var sepLine = new Kinetic.Rect({
	x: stage.getWidth() * 0.5 - 2,
	y: 0,
	width: 4,
	height: stage.getHeight() - 8,
	fill: 'rgba(240,240,240,0.15)',
});
layer.add(sepLine);

var canvasFont = 'DINPro, Calibri, Open Sans, Source Sans Pro, sans-serif';
var regularLaneChangeText = $('#regularText').text();
var symmetricLaneChangeText = $('#symmetricText').text();

var regularLaneChangeText = new Kinetic.Text({
	x: stage.getWidth() * 0.25,
	y: 15,
	text: regularLaneChangeText,
	fontSize: 18,
	fontFamily: canvasFont,
	fill: 'rgb(240,240,240)',
	id: 'regularLaneChangeText'
});
regularLaneChangeText.setOffset({
	x: regularLaneChangeText.getWidth() * 0.5
});
var symmetricLaneChangeText = new Kinetic.Text({
	x: stage.getWidth() * 0.75,
	y: 15,
	text: symmetricLaneChangeText,
	fontSize: 18,
	fontFamily: canvasFont,
	fill: 'rgb(240,240,240)',
	id: 'symmetricLaneChangeText'
});
symmetricLaneChangeText.setOffset({
	x: symmetricLaneChangeText.getWidth() * 0.5
});
layer.add(regularLaneChangeText);
layer.add(symmetricLaneChangeText);

var courseLineRegular = new Kinetic.Line({
	points: [
		stage.getWidth() * 0.125, stage.getHeight() - 15, 
		stage.getWidth() * 0.125, 100, 
		stage.getWidth() * 0.375, 100,
		stage.getWidth() * 0.375, stage.getHeight() - 15
	],
	stroke: 'rgba(240,240,240, 0.5)',
	strokeWidth: 2,
	lineJoin: 'round',
	dash: [5, 5]
});
layer.add(courseLineRegular);
var courseLineSymmetric = new Kinetic.Line({
	points: [
		stage.getWidth() * 0.625, stage.getHeight() - 15, 
		stage.getWidth() * 0.625, 100, 
		stage.getWidth() * 0.875, 100,
		stage.getWidth() * 0.875, stage.getHeight() - 15
	],
	stroke: 'rgba(240,240,240, 0.5)',
	strokeWidth: 2,
	lineJoin: 'round',
	dash: [5, 5]
});
layer.add(courseLineSymmetric);

var regularCircle = new Kinetic.Circle({
	x: stage.getWidth() * 0.125,
	y: stage.getHeight() - 15,
	radius: 10,
	fill: 'rgba(240,240,240, 0.75)',
	stroke: 'rgba(0,0,0,0.5)',
	strokeWidth: 2
});
layer.add(regularCircle);

var symmetricCircle = new Kinetic.Circle({
	x: stage.getWidth() * 0.625,
	y: stage.getHeight() - 15,
	radius: 10,
	fill: 'rgba(240,240,240, 0.75)',
	stroke: 'rgba(0,0,0,0.5)',
	strokeWidth: 2
});
layer.add(symmetricCircle);

stage.add(layer);
stage.draw()

var regularCourseAnim = new Kinetic.Tween({
	node: regularCircle,
	duration: 2,
	y: 100,
	easing: Kinetic.Easings.EaseInOut,
	onFinish: function() {
		new Kinetic.Tween({
			node: regularCircle,
			duration: 2,
			x: stage.getWidth() * 0.375,
			easing: Kinetic.Easings.EaseInOut,
			onFinish: function() {
				new Kinetic.Tween({
					node: regularCircle,
					duration: 2,
					y: stage.getHeight() - 15,
					easing: Kinetic.Easings.EaseInOut
				}).play();
			}
		}).play();
	}
});
var symmetricCourseAnim = new Kinetic.Tween({
	node: symmetricCircle,
	duration: 2,
	y: 100,
	easing: Kinetic.Easings.EaseInOut,
	onFinish: function() {
		new Kinetic.Tween({
			node: symmetricCircle,
			duration: 2,
			x: stage.getWidth() * 0.875,
			easing: Kinetic.Easings.EaseInOut,
			onFinish: function(right) {
				new Kinetic.Tween({
					node: symmetricCircle,
					duration: 2,
					y: stage.getHeight() - 15,
					easing: Kinetic.Easings.EaseInOut
				}).play();
			}
		}).play();
	}
});

var lineWidth = 2, //stage.getWidth() * 1/8;
	orange = 'rgba(255,78,0,1)',
	blue = 'rgba(0,156,255,1)';

// regular left
var regularLeft1 = new Kinetic.Line({
	points: [ stage.getWidth() * 1/16, stage.getHeight() - 15, stage.getWidth() * 1/16, stage.getHeight() - 15 ],
	stroke: orange,
	strokeWidth: lineWidth,
	// dash: [10,5]
});
layer.add(regularLeft1);
var regularLeft2 = new Kinetic.Line({
	points: [ stage.getWidth() * 1/16, 65, stage.getWidth() * 1/16, 65 ],
	stroke: orange,
	strokeWidth: lineWidth,
	// dash: [10,5]
});
layer.add(regularLeft2);
var regularLeft3 = new Kinetic.Line({
	points: [ stage.getWidth() * 7/16, 65, stage.getWidth() * 7/16, 65 ],
	stroke: orange,
	strokeWidth: lineWidth,
	// dash: [10,5]
});
layer.add(regularLeft3);

var a, b, c;
a = new Kinetic.Tween({
	node: regularLeft1,
	points: [ stage.getWidth() * 1/16, stage.getHeight() - 15, stage.getWidth() * 1/16, 65 ],
	duration: 2,
	easing: Kinetic.Easings.EaseInOut,
	onFinish: function() {
		b.play();
	}
});
b = new Kinetic.Tween({
	node: regularLeft2,
	points: [ stage.getWidth() * 1/16, 65, stage.getWidth() * 7/16, 65 ],
	duration: 2,
	easing: Kinetic.Easings.EaseInOut,
	onFinish: function() {
		c.play();
	}
});
c = new Kinetic.Tween({
	node: regularLeft3,
	points: [ stage.getWidth() * 7/16, 65, stage.getWidth() * 7/16, stage.getHeight() - 15 ],
	duration: 2,
	easing: Kinetic.Easings.EaseInOut,
	onFinish: function() {
	}
});

// regular right
var regularRight1 = new Kinetic.Line({
	points: [ stage.getWidth() * 3/16, stage.getHeight() - 15, stage.getWidth() * 3/16, stage.getHeight() - 15 ],
	stroke: blue,
	strokeWidth: lineWidth,
	// dash: [10,5]
});
layer.add(regularRight1);
var regularRight2 = new Kinetic.Line({
	points: [ stage.getWidth() * 3/16, 80, stage.getWidth() * 3/16, 80 ],
	stroke: blue,
	strokeWidth: lineWidth,
	// dash: [10,5]
});
layer.add(regularRight2);
var regularRight3 = new Kinetic.Line({
	points: [ stage.getWidth() * 5/16, 80, stage.getWidth() * 5/16, 80 ],
	stroke: blue,
	strokeWidth: lineWidth,
	// dash: [10,5]
});
layer.add(regularRight3);

var d, e, f;
d = new Kinetic.Tween({
	node: regularRight1,
	points: [ stage.getWidth() * 3/16, stage.getHeight() - 15, stage.getWidth() * 3/16, 80 ],
	duration: 2,
	easing: Kinetic.Easings.EaseInOut,
	onFinish: function() {
		e.play();
	}
});
e = new Kinetic.Tween({
	node: regularRight2,
	points: [ stage.getWidth() * 3/16, 80, stage.getWidth() * 5/16, 80 ],
	duration: 2,
	easing: Kinetic.Easings.EaseInOut,
	onFinish: function() {
		f.play();
	}
});
f = new Kinetic.Tween({
	node: regularRight3,
	points: [ stage.getWidth() * 5/16, 80, stage.getWidth() * 5/16, stage.getHeight() - 15 ],
	duration: 2,
	easing: Kinetic.Easings.EaseInOut,
	onFinish: function() {
	}
});

// symmetric left
var symmetricLeft1 = new Kinetic.Line({
	points: [ stage.getWidth() * 9/16, stage.getHeight() - 15, stage.getWidth() * 9/16, stage.getHeight() - 15 ],
	stroke: orange,
	strokeWidth: lineWidth,
	// dash: [10,5]
});
layer.add(symmetricLeft1);
var symmetricLeft2 = new Kinetic.Line({
	points: [ stage.getWidth() * 9/16, 65, stage.getWidth() * 9/16, 65 ],
	stroke: orange,
	strokeWidth: lineWidth,
	// dash: [10,5]
});
layer.add(symmetricLeft2);
var symmetricLeft3 = new Kinetic.Line({
	points: [ stage.getWidth() * 13/16, 65, stage.getWidth() * 13/16, 65 ],
	stroke: orange,
	strokeWidth: lineWidth,
	// dash: [10,5]
});
layer.add(symmetricLeft3);

var g, h, i;
g = new Kinetic.Tween({
	node: symmetricLeft1,
	points: [ stage.getWidth() * 9/16, stage.getHeight() - 15, stage.getWidth() * 9/16, 65 ],
	duration: 2,
	easing: Kinetic.Easings.EaseInOut,
	onFinish: function() {
		h.play();
	}
});
h = new Kinetic.Tween({
	node: symmetricLeft2,
	points: [ stage.getWidth() * 9/16, 65, stage.getWidth() * 13/16, 65 ],
	duration: 2,
	easing: Kinetic.Easings.EaseInOut,
	onFinish: function() {
		i.play();
	}
});
i = new Kinetic.Tween({
	node: symmetricLeft3,
	points: [ stage.getWidth() * 13/16, 65, stage.getWidth() * 13/16, stage.getHeight() - 15 ],
	duration: 2,
	easing: Kinetic.Easings.EaseInOut,
	onFinish: function() {
	}
});

// symmetric right
var symmetricRight1 = new Kinetic.Line({
	points: [ stage.getWidth() * 11/16, stage.getHeight() - 15, stage.getWidth() * 11/16, stage.getHeight() - 15 ],
	stroke: blue,
	strokeWidth: lineWidth,
	// dash: [10,5]
});
layer.add(symmetricRight1);
var symmetricRight2 = new Kinetic.Line({
	points: [ stage.getWidth() * 11/16, 80, stage.getWidth() * 11/16, 80 ],
	stroke: blue,
	strokeWidth: lineWidth,
	// dash: [10,5]
});
layer.add(symmetricRight2);
var symmetricRight3 = new Kinetic.Line({
	points: [ stage.getWidth() * 15/16, 80, stage.getWidth() * 15/16, 80 ],
	stroke: blue,
	strokeWidth: lineWidth,
	// dash: [10,5]
});
layer.add(symmetricRight3);

var j, k, l;
j = new Kinetic.Tween({
	node: symmetricRight1,
	points: [ stage.getWidth() * 11/16, stage.getHeight() - 15, stage.getWidth() * 11/16, 80 ],
	duration: 2,
	easing: Kinetic.Easings.EaseInOut,
	onFinish: function() {
		k.play();
	}
});
k = new Kinetic.Tween({
	node: symmetricRight2,
	points: [ stage.getWidth() * 11/16, 80, stage.getWidth() * 15/16, 80 ],
	duration: 2,
	easing: Kinetic.Easings.EaseInOut,
	onFinish: function() {
		l.play();
	}
});
l = new Kinetic.Tween({
	node: symmetricRight3,
	points: [ stage.getWidth() * 15/16, 80, stage.getWidth() * 15/16, stage.getHeight() - 15 ],
	duration: 2,
	easing: Kinetic.Easings.EaseInOut,
	onFinish: function() {
	}
});


$('#playLaneOffsets').show().on('click', function(evt) {
	evt.preventDefault();

	// regular
	regularCircle.setX(stage.getWidth() * 0.125); // fake reset
	regularCircle.setY(stage.getHeight() - 15); // fake reset
	regularCourseAnim.reset().play();
	c.reset();
	b.reset();
	a.reset().play();
	f.reset();
	e.reset();
	d.reset().play();

	// symmetric
	symmetricCircle.setX(stage.getWidth() * 0.625); // fake reset
	symmetricCircle.setY(stage.getHeight() - 15); // fake reset
	symmetricCourseAnim.reset().play();
	i.reset();
	h.reset();
	g.reset().play();
	l.reset();
	k.reset();
	j.reset().play();
});


/** ################################################################### **/


/** OFFSET CALCULATOR **/
$('#input').show();

var maxNumTools = 6;

var subs = $('#textElements').find('sub');
textElements = {
	courseWorkWidth: subs.filter('[data-text="courseWorkWidth"]').text(),
	tool: subs.filter('[data-text="tool"]').text(),
	offset: subs.filter('[data-text="offset"]').text()
};

var amountEl = $('#amount'),
    workWidthEl = $('#workWidth');
    
amountEl.find('option').each(function() {
	if (parseFloat($(this).attr('value')) > maxNumTools) {
		$(this).remove();
	};
});

$('#amount, #workWidth').on('change', function() {
    updateOffsetData();
});

$('#amountplus, #amountminus').on('click', function() {
	var change = 1;
	if ($(this).attr('id') == 'amountplus') {
		change = 1;
	} else if ($(this).attr('id') == 'amountminus'){
		change = -1;
	};

	var oldVal = parseFloat(amountEl.val());
		newVal = oldVal + change;

	if (newVal <= 2) { 
		newVal = 2;
		$('#amountminus').addClass('hidden');
	} else {
		$('#amountminus').removeClass('hidden');
	};
	if (newVal >= maxNumTools) { 
		newVal = maxNumTools; 
		$('#amountplus').addClass('hidden');
	} else {
		$('#amountplus').removeClass('hidden');
	};

	amountEl.val(newVal);
	updateOffsetData();
});

var stage = new Kinetic.Stage({
	container: 'laneOffsetStage',
	width: $('#faqOffset').width(),
	height: 400,
	fill: 'rgba(240,240,240,0)'
});

var layer = new Kinetic.Layer();
var infoLayer = new Kinetic.Layer();
var toolWidthLayer = new Kinetic.Layer();
var toolCourseLayer = new Kinetic.Layer();
var toolTextLayer = new Kinetic.Layer();

var field = new Kinetic.Rect({
	x: 0,
	y: 0,
	width: stage.getWidth(),
	height: stage.getHeight() - 100,
	fill: 'rgba(240,240,240,0)',
});
layer.add(field);
stage.add(layer);
stage.add(infoLayer);
stage.add(toolWidthLayer);
stage.add(toolCourseLayer);
stage.add(toolTextLayer);

var toolColors = [
	{ r:  0, g:198, b:255 },
	{ r: 83, g:217, b: 30 },
	{ r:255, g:156, b:  0 },
	{ r:184, g: 19, b: 19 },
	{ r: 31, g: 24, b:122 },
	{ r:255, g:222, b:  0 },
];

var resultData = {
		avg: 0,
		totalWorkWidth: 0,
		toolOffsets: []
	};

function initiateOffsetData() {
	resultData.toolOffsets = [];

    var num = parseFloat(amountEl.val()),
        ww = parseFloat(workWidthEl.val());

	resultData.totalWorkWidth = ww * num,
	//resultData.avg = num/2 + 0.5;
	resultData.avg = (num+1) * 0.5;
    for (var i=1; i<=num; i++) {
		var toolOffset = -(resultData.avg-i) * ww;
		resultData.toolOffsets.push(toolOffset);
    };
};

function updateOffsetData() {
	initiateOffsetData();

	$('#amountText').text(amountEl.val());

	var num = amountEl.val(),
		ww = workWidthEl.val(),
		canvasMultiplier = stage.getWidth()/resultData.totalWorkWidth;
		animDuration = 0.4,
		animEasing = 'ease-in-out';

	var totalWidthText = stage.get('#totalWidthText')[0];
	totalWidthText.setText(textElements.courseWorkWidth + ': ' + resultData.totalWorkWidth + 'm');

	totalWidthText.setX(stage.getWidth() * 0.5);
	totalWidthText.setOffset({
		x: totalWidthText.getWidth() * 0.5
	});


	for (var i=0; i<maxNumTools; i++) {
		var toolRect = stage.get('#toolRect_'+i)[0];
		var toolCourse = stage.get('#toolCourse_'+i)[0];
		//var toolTextBg = stage.get('#toolTextBg_'+i)[0];
		var toolText = stage.get('#toolText_'+i)[0];


		var tween = new Kinetic.Tween({
			node: toolRect,
			x: i * ww * canvasMultiplier,
			width: ww * canvasMultiplier,
			duration: animDuration
			// easing: animEasing
		});
		tween.play();


		var rectCenter = (i * ww * canvasMultiplier) + (ww * 0.5 * canvasMultiplier);

		tween = new Kinetic.Tween({
			node: toolCourse,
			x: rectCenter - 1,
			// points: [rectCenter, stage.getHeight() - 50, rectCenter, 50],
			duration: animDuration
			// easing: animEasing
		});
		tween.play();

		var text = textElements.tool + ' #' + parseFloat(i+1);
		if (i < num) { 
			text = textElements.tool + ' #' + parseFloat(i+1) + '\n' + textElements.offset + ': ' + resultData.toolOffsets[i] + 'm';
		};
		toolText.setText(text);
		tween = new Kinetic.Tween({
			node: toolText,
			x: rectCenter - toolText.getWidth() * 0.5,
			duration: animDuration
			// easing: animEasing
		});
		tween.play();
	};
	stage.draw()
};

function firstDraw() {
	var num = amountEl.val(),
		ww = workWidthEl.val();

	var canvasFont = 'DINPro, Calibri, Open Sans, Source Sans Pro';

	var totalWidthText = new Kinetic.Text({
		x: stage.getWidth() * 0.5,
		y: 15,
		text: textElements.courseWorkWidth + ': ' + resultData.totalWorkWidth + 'm',
		fontSize: 16,
		fontFamily: canvasFont,
		fill: 'rgb(240,240,240)',
		id: 'totalWidthText'
	});
	totalWidthText.setOffset({
		x: totalWidthText.getWidth() * 0.5
	});
	infoLayer.add(totalWidthText);

	var totalWidthLineY = totalWidthText.getY() + totalWidthText.getHeight() * 0.5;
	var totalWidthLineLeft = new Kinetic.Line({
		points: [0, totalWidthLineY, stage.getWidth() * 0.5 - totalWidthText.getWidth()  * 0.5 - 10, totalWidthLineY],
		stroke: 'rgb(240,240,240)',
		strokeWidth: 2,
		lineJoin: 'round',
	});
	var totalWidthLineRight = new Kinetic.Line({
		points: [stage.getWidth() * 0.5 + totalWidthText.getWidth() * 0.5 + 10, totalWidthLineY, stage.getWidth(), totalWidthLineY],
		stroke: 'rgb(240,240,240)',
		strokeWidth: 2,
		lineJoin: 'round',
	});
	infoLayer.add(totalWidthLineLeft);
	infoLayer.add(totalWidthLineRight);

	var canvasMultiplier = stage.getWidth()/resultData.totalWorkWidth;
	var mainLineWidth = 0.25;
	var centerX = resultData.totalWorkWidth * 0.5 * canvasMultiplier
	var course = new Kinetic.Line({
		points: [centerX, stage.getHeight() - 50, centerX, 50],
		stroke: 'rgba(255,0,186,0.5)',
		strokeWidth: 4,
		lineJoin: 'round',
		dash: [10, 10]
	});
	infoLayer.add(course);


	for (var i=0; i<maxNumTools; i++) {
		var rectColor, strokeColor, lineColor;
		var c = i;
		while (c > toolColors.length - 1) {
			c -= toolColors.length;
		};
		var color = toolColors[c];

		var rectColor   = 'rgba(' + color.r + ', ' + color.g + ', ' + color.b + ', 0.5)';
		var strokeColor = 'rgba(' + color.r + ', ' + color.g + ', ' + color.b + ', 0.8)';
		var lineColor   = 'rgba(' + color.r + ', ' + color.g + ', ' + color.b + ', 1.0)';

		var toolRect = new Kinetic.Rect({
			x: i * ww * canvasMultiplier,
			y: 150,
			width: ww * canvasMultiplier,
			height: stage.getHeight() - 200,
			fill: rectColor,
			stroke: strokeColor,
			strokeWidth: 1,
			id: 'toolRect_' + i
		});
		toolWidthLayer.add(toolRect);

		var rectCenter = toolRect.getWidth() * 0.5 + (i * ww * canvasMultiplier);
		var toolCourse = new Kinetic.Line({
			x: rectCenter,
			points: [0, stage.getHeight() - 50, 0, 50],
			stroke: lineColor,
			strokeWidth: 2,
			lineJoin: 'round',
			dash: [10, 10],
			id: 'toolCourse_' + i
		});
		toolCourseLayer.add(toolCourse);

		//text
		var text = textElements.tool +' #' + parseFloat(i+1) + '\n' + textElements.offset + ': ';
		if (i < num) { 
			text += resultData.toolOffsets[i] + 'm';
		};
		var toolText = new Kinetic.Text({
			y: 365,
			text: text,
			fontSize: 16,
			fontFamily: canvasFont,
			fill: 'rgb(250,250,250)',
			align: 'center',
			id: 'toolText_' + i
		});
		toolText.setX(rectCenter - toolText.getWidth() * 0.5);
		toolTextLayer.add(toolText);

	};

	stage.draw();
}; //END firstDraw()

initiateOffsetData();
firstDraw();


$('#save').show().on('click', function(evt) {
	evt.preventDefault();
	stage.toDataURL({
		callback: function(dataUrl) {
			var tab = window.open(dataUrl, '_parent');
			tab.focus();
		}
	});
});


}); })(jQuery); //END document.ready