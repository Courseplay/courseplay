die folgenden dateien in den order "specializations" des mods kopieren:

courseplay.lua
arrow.png



in die moddesc eintragen:

   <l10n>
    <text name="PointRecordStart">
		<en>Record Course Start</en>
		<de>Kurs aufzeichnung starten</de>
	</text>
	<text name="PointRecordStop">
		<en>Record Course Stop</en>
		<de>Kurs aufzeichnung stoppen</de>
	</text>
	<text name="CoursePlayStart">
		<en>Drive Course</en>
		<de>Kurs abfahren</de>
	</text>
	<text name="CoursePlayStop">
		<en>Drive stop</en>
		<de>stop abfahren</de>
	</text>
	<text name="CoursePlayRound">
	    <en>Kurs:  Round Course</en>
	    <de>Kurs: Rundkurs</de>
	</text>
	<text name="CoursePlayReturn">
		<en>Course: return</en>
		<de>Kurs: Hin und Zurück</de>
	</text>
	</l10n>

	<specializations>
        ...
		...
		...
		<specialization name="courseplay" className="courseplay" filename="specializations/courseplay.lua"/>
    </specializations>
    <vehicleTypes>
		...
		...
		...		
		<specialization name="courseplay" />		
    </vehicleTypes>
	
	<inputBindings>
        ...
		...
		...
        <input name="PointRecord" key1="KEY_k" button="" />
        <input name="CoursePlay" key1="KEY_l" button="" />
	<input name ="CourseMode"			key1="KEY_j" />
    </inputBindings>


anleitung zum fahren:

am startpunkt staste K
strecke abfahren
am zielpunkt wieder taste k, DANN erst anhalten(wird noch gefixt)

taste L zum losfahren,der traktor fährt erst los wenn man ca 15 meter vom startpunkt/zielpunkt entfernt ist (dem pfeil nach fahren)
