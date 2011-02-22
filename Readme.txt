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
	<text name="CourseLoad">
		<en>load course</en>
		<de>Kurs laden</de>
	</text>
	<text name="CourseSave">
		<en>save course</en>
		<de>Kurs speichern</de>
	</text>		
	<text name="CourseReset">
		<en>reset course</en>
		<de>Kurs zurücksetzen</de>
	</text>		
	<text name="CourseWaitpoint">
			<en>set waitpoint</en>
			<de>Wartepunkt setzen</de>
		</text>		
		<text name="CourseWaitpoinStart">
			<en>start</en>
			<de>weiterfahren</de>
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
       	<input name ="CourseMode"			key1="KEY_k" />
	<input name="PointRecord" key1="KEY_l" button="" />
    <input name="CoursePlay" key1="KEY_j" button="" />
	<input name="CourseSave" key1="KEY_s" button="" />
	<input name="CourseLoad" key1="KEY_o" button="" />
	<input name="CourseReset" key1="KEY_r" button="" />
	<input name="CourseWait" key1="KEY_KP_0" button="" />
    </inputBindings>


anleitung zum fahren:

am startpunkt staste K
strecke abfahren
am zielpunkt wieder taste k, DANN erst anhalten(wird noch gefixt)

taste J zum losfahren,der traktor fährt erst los wenn man ca 15 meter vom startpunkt/zielpunkt entfernt ist (dem pfeil nach fahren)
