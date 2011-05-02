Courseplay - Abfahrhelfer für LS 2011 v 1.2

Inhaltsverzeichnis

I. Changelog
II.   Installationsanweisung
III.  Bedienungsanleitung
IV. Credits

I. Changelog - Änderungen seit Version 1.0

Als neue Funktionen sind im wesentlichen der Düngemodus und das Rückwärtsfahren hinzugekommen. Außerdem wurde das Fahrverhalten (besonders in Kurven) verbessert und es werden mehr EntladeTrigger (Gras und Silage) erkannt.
Zudem kann man jetzt gespeicherte Kurse kombinieren indem man mehrere Kurse hintereinander lädt. Wenn man nur einen neuen Kurs laden will muss man allerdings jetzt vorher die Wegpunkte des alten zurücksetzen.
Außerdem ist der Abfahrhelfer jetzt kein "hireable" mehr, das heißt er verbraucht jetzt Benzin(Dünger..) beim Fahren. Damit der Abfahrer nicht einfach irgendwo stehen bleibt bekommt man eine Warnung sobald der Tank fast leer ist und bei einem minimalen Tankinhalt bleibt der Abfahrhelfer stehen damit man ihn noch bis zur Zapfsäule bekommt.
Im Menu wurde noch der "BUG" behoben, dass man das Menu mit allen Maustasten steuern konnte.
Natürlich gab es noch viele weitere kleine Bugfixes.

Dieses Mal geht ein besonders großer Dank an Wolverine, der einen Großteil dieses Updates (Düngemodus und Rückwärtsfahren) implementiert hat.
Wir haben weiterhin an einer Version 2 die komplett multiplayerfähig ist, die aktuelle Version 1.20 ist aber zumindest im MP vom Host bedienbar.

II. Installationsanweisung

1. Das Archiv aacourseplay.zip in das Verzeichnis C:\Users\dein Username\MyGames\FarmingSimulator2011\mods kopieren

ACHTUNG: Beim Update von version 1.0 müsst ihr NUR die alte aacourseplay.zip durch die neue ersetzen, es muss NICHTS am Schlepper geändert werden.

2. Jetzt das Archiv des Schleppers entpacken den du mit dem Abfahrhelfer versehen willst und in der moddesc.xml folgende Einträge machen

<vehicleTypes>
        ...
        ...
        ...
        <specialization name="courseplay" />  <<-- Diese Zeile muss eingetragen werden
</vehicleTypes>

anschließend die Dateien wieder zurückpacken.

Das ganze Entpacken und Packen kann man sich mit dem Totalcommander oder Winrar sparen, da er das Entpacken und Packen automatisch macht.
Hier einfach das Archiv öffnen, Datei bearbeiten, speichern, schließen und zurückpacken bestätigen.



III. Bedienungsanleitung


	Steuerung:
	
		Die Steuerung des Abfahrhelfers funktioniert im wesentlichem mit der Maus da freie Tasten im Landwirtschafts Simulator ja sehr rah sind.
		Mit einem Klick auf die rechte Maustaste aktiviert ihr das Courseplay HUD in dem ihr den Abfahrer konfigurieren könnt. Zusätzlich sind einige Funktionen wie Abfahrer starten und stoppen auch über die Tastatur über die Tasten NUMPAD 7 bis NUMPAD 9 belegt.
	
	HUD:
	
		Wenn ihr das HUD öffnet wird automatisch die Maussteuerung aktiviert. Das heißt ihr könnt euch mit der Maus nicht mehr umgucken. Um die Maussteuerung zu deaktivieren müsst ihr einfach nochmal auf die rechte Maustaste klicken.
		Alternativ könnt ihr auch auf das rote X oben rechts im HUD klicken. Dabei wird das HUD geschlossen und die Maussteuerung wieder deaktiviert.
	
		Das HUD ist in mehrere Unterseiten unterteilt. Diese könnt ihr mit den blauen Pfeilen im oberen Bereich des HUDs wechseln.
		Im mittleren Bereich des HUDs könnt ihr auf jeder Unterseite verschiede Einstellungen vornehmen oder Befehle geben. Klickt dazu einfach auf die gewünschte Aktion.
	
		Im unteren Bereich des HUDs findet ihr Infos über euren Abfahrer den geladenen Kurs und den aktuellen Status. Dort könnt ihr durch klick auf die Diskette euren eingefahrenen Kurs auch speichern.
	
	HUD "Abfahrhelfer Steuerung":
	
		Kursaufzeichnung beginnen:
			
			Mit dieser Option wird der Aufnahmemodus des Abfahrhelfers aktiviert. Ihr könnt damit den Kurs einfahren den der Abfahrer später fahren soll.
			Bei Aktivierung werden anfangs drei Fässchen im Abstand von 10-20 Metern gesetzt. Ihr solltet darauf achten, dass ihr bis zum dritten Fass nach Möglichkeit geradeaus fahrt.
			Wenn ihr diese Funktion aktiviert habt könnt ihr mit der rechten Maustaste die Maussteuerung deaktivieren damit ihr euch beim Einfahren des Kurses auch umschauen könnt.
		
		Kursaufzeichnung beenden:
			
			Diese Aktion ist nur im Aufnahmemodus vergügbar und dient dazu diesen zu beenden. Klickt auf diese Funktion wenn ihr den Endpunkt eurer eingefahrenen Route erreicht habt.
			Es empfiehlt sich, dass der Endpunkt etwa 10 Meter vor dem Startpunkt liegt und dass man grob aus der Richtung kommt in die der Abfahrer beim Startpunkt auch weiterfahren soll.
			
		Hier Wartepunkt setzen:
		
			Im Aufnahmemodus habt ihr die Möglichkeit auf der Strecke Wartepunkte zu setzen. An diesen Punkten wird der Abfahrer später beim Abfahren anhalten bis man ihn manuell weiter schickt.
			Wenn ein Abfahrer einen Wartepunkt erreicht hat wird euch das am unteren Bildschirmrand angezeigt.
			
		Abfahrer einstellen:
		
			Wenn ihr einen Kurs eingefahren habt könnt ihr jetzt den Abfahrer einstellen. Dabei wird der Abfahrhelfer aktiviert und fährt brav seine Route ab.
			
		Abfahrer entlassen:
			
			Den aktivierten Abfahrer könnt ihr natürlich auch jederzeit entlassen bzw. anhalten.
			Wenn ihr den Abfahrhelfer später wieder aktiviert wird er seine Route am letzen Punkt fortführen.
			
		weiterfahren:
		
			Diese Option steht euch zur Verfügung wenn der Abfahrer einen Wartepunkt erreicht hat.
			
		Abfahrer-Typ wechseln:
		
			Damit der Abfahrhelfer möglichst viele Aufgaben erledigen kann gibt es verschiedene Abfahrhelfer Typen.
			Der aktuelle Typ wird im unteren Bereich des HUDs angezeigt. Mit klick auf diese Aktion könnt ihr die Typen durchgehen.
			
			Typ: Abfahrer
			
				Der Typ Abfahrer wartet am Startpunkt bis er voll beladen ist und fährt erst dann die Route ab. Wenn er auf seiner Route über eine Abkippstelle kommt hält er an und entleert seine(n) Anhänger.
				Man kann dem Abfahrer am Startpunkt allerdings auch sagen, dass er sofort abfahren soll.
				
				
			Typ: Kombiniert
			
				Der Kombinierte Modus ist ähnlich wie der Abfahrer Modus mit dem Unterschied, dass der Abfahrer am Startpunkt nicht wartet bis er beladen ist sondern selbstständig zu einem Drescher oder Häcksler auf dem aktuellen Feld fährt und diese bedient.
				Wenn alle Hänger voll sind fährt der Abfahrer das zweite Fässchen auf seiner Route an und fährt von da an die Route ab wie der normale Abfahrer.
				Damit der kombinierte Modus funktioniert muss der Startpunkt des Abfahrers unbedingt auf dem gleichen Feld liegen auf dem der oder die Drescher sind.
				
			Typ: Überladewagen
				
				Beim Typ Überladewagen fährt der Abfahrer auch direkt zum Drescher oder Häcksler und fährt anschließend seine Route ab. Der Unterschied hierbei ist, dass der Überladewagen "Wartepunkte" als "Abladepunkte" nutzt.
				Wenn der Überladewagen also voll ist fährt er seine Route bis zum Wartepunkt ab und fährt dort automatisch weiter, wenn der Überladewagen leer ist.
				
			Typ: Überführung
			
				In diesem Modus fährt der Abfahrer lediglich seine Route ab. Er wartet nicht am Startpunkt und wird an Abladestellen auch nicht entladen.
				Dieser Modus eignet sich in Verbindung mit Wartepunkten um Gerätschaften zum Feld zu bringen oder zum Beispiel auch auf andere Höfe.
			
			Typ: Düngen
			
				Im Düngemodus füllt der Abfahrhelfer am Startpunkt eine Spritze oder ein Güllefass und fährt dann seine Route ab. Man fährt mit dem Abfahrhelfer zum Feld, setzt einen Wartepunkt an der Stelle an der er mit dem Düngen beginnen soll, fährt das Feld ab und setzt einen Wartepunkt am Feldende.
				Beim Abfahren klappt der Abfahrhelfer automatisch die Spritze/Güllefass aus und schaltet es an, fährt das Feld ab bis der Tank leer ist und fährt zurück zum auftanken. Nach dem Auftanken macht er an der Position weiter an der er aufgehört hat.
				 
		
		Wegpunkte löschen:
			
			Wenn ein Kurs eingefahren ist kannst du über diese Option den Kurs wieder zurücksetzen. Dabei wird der gespeicherte Kurs nicht aus der Konfigurationsdaten gelöscht sondern nur der aktuelle Abfahrer wieder zurückgesetzt.
			
		
	HUD Kurs speichern
			 
		Im unteren Breich des Huds findet ihr eine Diskette. Wenn ihr einen Kurs eingefahren habt könnt ihr durch Klick auf die Diskette euren Kurs speichern.
		Dabei wird im oberen Bereich eine Eingabemaske angezeigt. Hier könnt ihr mit der Tastatur einen Namen für euren Kurs vergeben und diesen mit ENTER (Eingabetaste) bestätigen.
		
		Hinweis: Aktuell ist die Steuerung des Spiels im Speichermodus noch aktiv. Das heißt wenn ihr zum Beispiel "e" drückt steigt ihr leider noch aus dem Fahrzeug aus.
		In diesem Fall einfach wieder einsteigen und weiter tippen. Dieses Problem wird in einer späteren Version natürlich behoben.
		
	
	HUD "Kurse verwalten":
	
		Auf diser Unterseite des HUD findet ihr eine Übersicht eurer gespeicherten Kurse. Ihr könnt durch Klick auf das Ordner Symbol einen Kurs laden und durch einen Klick auf das rote X einen Kurs komplett löschen.
		ACHTUNG: seit version 1.2 müsst ihr wenn ihr einen neuen Kurs laden wollt erst die alten Wegpunkte zurücksetzen, sonst kombiniert ihr die beiden Kurse!
		Mit den blauen Pfeilen rechts oben und rechts unten könnt ihr durch die gespeicherten Kurse blättern.
		 
	HUD "Einstellungen Combi Modus":
	
		Diese Einstellungen gelten (wie der Name es andeutet) nur für den kombinierten Modus und den Überlademodus. Hiermit könnt ihr euren Abfahrer an den jeweiligen Drescher anpassen.
		Ihr könnt die Werte mit einem Klick auf das +/- Symbol daneben anpassen
		
		seitl. Abstand
			
			Dieser Wert definiert den seitlichen Abstand den ein Abfahrer zum Drescher oder Häcksler beim nebenher fahren einhalten soll.
			
		Start bei %:
			
			Dieser Wert legt fest ab welchem Füllstand des Dreschers der Abfahrer zu ihm fährt und ihn abtankt.
			Bei Häckslern wird durch diesen Wert festgelegt ab wann der zweite Abfahrer in der Kette dem ersten hinterherfahren soll.
			
		Wenderadius:
			
			Dieser Wert ist nur beim Häckseln wichtig und legt fest wie weit der Abfahrer beim Wenden des Häckslers von ihm wegfahren soll ohne ihm im Weg zu stehen.
			
		Pipe Abstand:
		
			Dieser Wert legt fest wie weit der Abfahrer beim nebenher fahren vor oder zurück fahren soll. Hiermit lässt sich der Abfahrer auf verschiedene Anhänger umstellen.
			
	HUD "Drescher verwalten":
	
		Auch diese Einstellungen sind nur für den kombinierten Modus relevant. Hier könnt ihr einstellen ob der Abfahrer sich automatisch einen Drescher oder Häcksler suchen soll (Standard) oder er einen manuell zugewiesenen Drescher nutzen soll.
		Wenn ihr einen Drescher manuell zuweist muss dieser auch nicht auf dem gleichen Feld stehen. Der Abfahrer fährt von seinem Startpunkt automatisch zum Drescher, egal wo dieser sich befindet.
		
		Interessant ist diese Einstellung vor allem bei großen oder hügeligen Feldern auf denen die automatische Zuweisung nicht immer funktioniert und auf Feldern ohne Grubbertextur z.B. Wiesen.
		
	HUD "Geschwidigkeiten":	
		
		Hier könnt ihr festlegen wie schnell euer Abfahrer fahren soll. Ich denke mal die Einstellungen sind selbst erklärend ;)


IV. Credits
	Lautschreier/Wolverin0815/Hummel	
	
	Die Entwicklung von courseplay war wohl etwas "ungewöhnlich"
	
	Die Grundversion hat "lautschreier" Anfang des Jahres begonnen. Diese konnte bereits Kurse einspeichern und abfahren.
	Mitte Februar wurde ich (hummel/netjungle) auf dieses Projekt bei planet-ls.de aufmerksam und beschloss da etwas mitzuhelfen.
	Aus "etwas mithelfen" wurde eine krankhafte Sucht und das Ergebnis heißt heute courseplay
	
	Ein besonderer Dank geht also selbstverstänlich an Lautschreier ohne den dieses Projekt wohl nie gestartet wäre. Vor allem dafür, dass er sein geistiges Eigentum zur Weiterentwicklung freigeben hat. (Open Source kann halt funktionieren)
	Weiterhin hat mich "Wolverin0815" auch sehr aktiv bei der Entwicklung unterstützt und unter anderem die erste Version des HUds integriert. Auch hier ein großer Dank für sein Engagement und seine Ideen.
	
	Zudem geht natürlich ein riesengroßes Dankeschön an alle die bei planet-ls.de fleißig getestet haben und ihre Ideen haben einfließen lassen. Die Enticklung hat mit soviel Feedback wirklich sehr viel Spaß gemacht.
			
	Auch beim Erfinder des Path Tractor aus LS 09 "micha381" an dem sich courseplay natürlich orientiert hat, muss ich mich bedanken.

	Und last but not least noch ein großes Dankeschön an mein Weibchen die mich in den letzten Wochen diesen "24/7 Wahnsinn" hat ausleben lassen ;)
