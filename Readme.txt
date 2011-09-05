Courseplay - Abfahrhelfer für LS 2011 v 2.2

Inhaltsverzeichnis

I. Changelog
II.   Installationsanweisung
III.  Bedienungsanleitung
IV. Credits
V. Videos

Ia. Changelog - Änderungen seit Version 2.11
	- Neuer Modus: Drescher fährt selbst zum abtanken
	- support für das BGA Silo des Giants DLC2
	- support für typanywhere mod
	- support für kommenden drescher autopilotenn 3.0.5
	- bessere unterstützung für ballensammelwagen
	- fehler beim befüllen von überladewagen und abfahrern auf der zweiten Runde gefixt
	- selten auftretenden multiplayer-callstacks behoben 


Ib. Changelog - Änderungen seit Version 2.0
	In der Version 2.0 waren leider noch einige Fehler die den Multiplayermodus gestört haben. Diese wurden behoben.
	Neu in dieser Version ist vor allem, dass ihr eure Schlepper nicht mehr mit courseplay nachrüsten müsst. Einfach den Mod ins Modverzeichnis und alle Fahrzeuge sind automatisch damit ausgestattet.
	Durch diese Änderung müsst ihr leider in allen bereits umgerüsteten Schleppern den Eintrag "<specialization name="courseplay" />" entfernen.
	Weiterhin wurde in dieser Version das Kombinieren von Kursen verbessert.
	
	Wichtig: die Datei aaacourseplay.zip (v2 und kleiner) MUSS aus dem Mod-Verzeichnis gelöscht werden.

Ic. Changelog - Änderungen seit Version 1.6

	Die größte Änderung im courseplay ist natürlich die Multiplayerfähigkeit. Dabei werden beim Spielstart alle Werte und sogar gespeicherte Kurse vom Host an die Clients übertragen. Das kann mitunter ein bisschen dauern ist aber notwendig.
	Neben zahlreichen Bugfixes und Performance-Optimierungen die hier nicht weiter erwähnt werden sollen gibt es im wesentlichen die folgende Neuerungen:

	Kursverwaltung: Gespeicherte Kurse werden jetzt alphabetisch sortiert und werden immmer global für alle Fahrzeuge gespeichert. Dadurch ist kein Synchronisieren der Kurse zwischen den einzelnen Fahrzeugen mehr nötig und der Speicherverbrauch ist drastisch gesunken.

	Kurse aufnhemen: Das Pausieren der Kursaufnahme wurde überarbeitet. Man kann jetzt die Kursaufzeichnung pausieren und die letzten Wegpunkte löschen. Dabei wird jetzt immer nur der letzte Wegpunkt angezeigt und nicht mehr alle.

	Neu: Kurs Offset

	Dieses Feature ist noch experimentell und soll dafür sorgen, dass der Schlepper den gespeicherten Kurs leicht versetzt abfährt. Gedacht ist dies zum Beispiel für Ballensammelwagen.

	Neue Kurskombination:

	Ihr könnt beim Einfahren eines Kurses jetzt Kreuzungspunkte setzen. Wenn ihr später mehrere Kurse hintereinander ladet werden diese immer am ersten gemeinsamen Kreuzungspunkt (Abstand unter 30 Metern!) zusammengefügt. Damit könnt ihr also auch Teile von Routen wieder verwenden.

	Das Rückwärtsfahren wurden optimiert und sollte jetzt wieder richtig funktionieren.

	Wenn ihr das Spiel speichert werden die Einstellungen eurer Abfahrer mit gespeichert. Nach dem Neuladen müsst ihr also normalerweise nichts mehr einstellen. Die zuvor geladenen Kurse und Einstellungen sollten komplett wieder verfügbar sein.

	Außerdem gibt es neue Symbole für die Wegpunkte und spezielle Wegpunkte wie Kreuzungspunkte und Startpunkte sind auch sichtbar wenn ihr nicht im Fahrzeug seid welches die Route gespeichert hat.


Id. Changelog - Änderungen seit Version 1.2

	Neu hinzugekommen sind vor allem der Feldmodus mit dem man Ballen pressen und Heusammeln kann. Der Güllemodus wurde weiter perfektioniert und es ist jetzt auch möglich den Abfahrhelfer in Drescher und Häcksler einzubauen.
	Damit kann man beispielsweise mit Dreschern im Helfermodus Kurse aufzeichnen lassen die man dann später für den Gülle- oder Feldmodus verändern kann.
	Zudem gibt es eine Steuerung des Abfahrhelfers aus dem Drescher heraus. Man kann einen Abfahrhelfer rufen, starten, stoppen und beim Häcksler die Seite des Abfahrers ändern.
	Beim Abfahrhelfer kann man jetzt einstellen bei wieviel Prozenz Füllstand er frühzeitig abfahren soll. Hat ein Abfahrer zum Beispiel einen Füllstand von 90% und der Drescher wendet am Ende des Feldes, fährt der Abfahrer gleich ab und wartet nicht auf das Wendemanöver.
	Zudem fährt der Überladewagen an seinem Überladepunkt wieder zurück aufs Feld wenn er einen gewissen Füllstand unterschritten hat und für etwa 20 Sekunden kein weiterer Abfahrer zum überladen konmmt.
	Außerdem wurrde gewünscht, dass der Abfahrhelfer auf der Straße seine Rundumleuchte einschaltet - das tut er jetzt ;)
	Dann gab es natürlich auch noch etwas Feintuning: Das unsinnige Kreiseln auf dem Feld sollte jetzt vorbei sein, HW80 Drehschemel und Agroliner Container werden jetzt auch unterstützt. 


Ie. Changelog - Änderungen seit Version 1.0

	Als neue Funktionen sind im wesentlichen der Düngemodus und das Rückwärtsfahren hinzugekommen. Außerdem wurde das Fahrverhalten (besonders in Kurven) verbessert und es werden mehr EntladeTrigger (Gras und Silage) erkannt.
	Zudem kann man jetzt gespeicherte Kurse kombinieren indem man mehrere Kurse hintereinander lädt. Wenn man nur einen neuen Kurs laden will muss man allerdings jetzt vorher die Wegpunkte des alten zurücksetzen.
	Außerdem ist der Abfahrhelfer jetzt kein "hireable" mehr, das heißt er verbraucht jetzt Benzin(Dünger..) beim Fahren. Damit der Abfahrer nicht einfach irgendwo stehen bleibt bekommt man eine Warnung sobald der Tank fast leer ist und bei einem minimalen Tankinhalt bleibt der Abfahrhelfer stehen damit man ihn noch bis zur Zapfsäule bekommt.
	Im Menu wurde noch der "BUG" behoben, dass man das Menu mit allen Maustasten steuern konnte.
	Natürlich gab es noch viele weitere kleine Bugfixes.

	Dieses Mal geht ein besonders großer Dank an Wolverine, der einen Großteil dieses Updates (Düngemodus und Rückwärtsfahren) implementiert hat.
	Wir haben weiterhin an einer Version 2 die komplett multiplayerfähig ist, die aktuelle Version 1.20 ist aber zumindest im MP vom Host bedienbar.



II. Installationsanweisung

1. Das Archiv ZZZ_courseplay.zip in das Verzeichnis C:\Users\dein Username\MyGames\FarmingSimulator2011\mods kopieren. Das War es!


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

		Kursaufzeichnung anhalten:

			Wenn die Kursaufzeichnung läuft könnt ihr mit dieser Funktion die Kursaufzeichnung pausieren. Es wird ein gelber Pfeil angezeigt der zum letzten Wegpunkt zeigt. Zusätzlich könnt ihr in diesem Modus auch den letzten Wegpunkt löschen.

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

			Typ: Feldarbeit (Ballenpressen, Schwadaufnahme)

				Der Feldarbeitsmodus funktioniert ähnlich wie der Düngemodus. Hierbei wird ein zuvor aufgezeichneter Kurs mit Feldgeschwindigkeit abgefahren.
				Als Besonderheit kann man in diesem Modus zum Beispiel eine Ballenpresse anhängen. Die Rundballenpresse hält hierbei an wenn sie voll ist und wirft den Ballen aus.
				Wenn man einen Ladewagen anhängt wird der Kurs abgefahren bis dieser voll ist, dann wird die letzte Position gespeichert und der Kurs abgefahren. Der Kurs sollte dann natürlich an einem Abladetrigger vorbei führen. Dort wird der Wagen entleert und dann fährt er zurück zum Feld und setzt seine Arbeit am letzten Punkt fort.
				Der Arbeitsbereich des Modus Feldarbeit muss wie im Düngemodus durch zwei Wartepunkte markiert werden.

			Typ: Drescher färht selbst zum abtanken

				Dieser Modus ist ähnlich dem des Überladewagens, nur eben für Drescher. Der Startpunkt der Route ist der Punkt den der Drescher anfährt wenn er den eingestellen Füllstand erreicht hat. Er fährt dann die Route bis zum
				1. Wartepunkt ab. Am Wartepunkt tankt der Drescher ab und fährt, sobald er leer ist die Route weiter. Der Endpunkt der Route ist der Punkt an dem der Drescher den Helfer aktiviert. Wenn er bereits auf dieser Route gedroschen hat, fährt er nach dem abtanken den letzten Wegpunkt an und dann weiter an den Punkt an dem der Drescher 
				weggefahren ist.
 

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
		Hinweis zum Kombinieren von Kursen: Das Ordner Symbol ohne den blauen Pfeil kombiniert die Kurse am ersten gemeinsamen Kreuzungspunkt, der mit dem blauen Pfeil hängt die Kurse einfach hintereinander.

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
	Lautschreier/Wolverin0815/Bastian82/Hummel	

	Die Entwicklung von courseplay war wohl etwas "ungewöhnlich"

	Die Grundversion hat "lautschreier" Anfang des Jahres begonnen. Diese konnte bereits Kurse einspeichern und abfahren.
	Mitte Februar wurde ich (hummel/netjungle) auf dieses Projekt bei planet-ls.de aufmerksam und beschloss da etwas mitzuhelfen.
	Aus "etwas mithelfen" wurde eine krankhafte Sucht und das Ergebnis heißt heute courseplay

	Ein besonderer Dank geht also selbstverstänlich an Lautschreier ohne den dieses Projekt wohl nie gestartet wäre. Vor allem dafür, dass er sein geistiges Eigentum zur Weiterentwicklung freigeben hat. (Open Source kann halt funktionieren)
	Weiterhin hat mich "Wolverin0815" auch sehr aktiv bei der Entwicklung unterstützt und unter anderem die erste Version des HUds integriert. Auch hier ein großer Dank für sein Engagement und seine Ideen.

	Den Feldarbeitsmodus mit automatischem Pressen und Schwadaufnahme mit einem Ladewagen verdanken wir bastian82

	Zudem geht natürlich ein riesengroßes Dankeschön an alle die bei planet-ls.de fleißig getestet haben und ihre Ideen haben einfließen lassen. Die Enticklung hat mit soviel Feedback wirklich sehr viel Spaß gemacht.

	Auch beim Erfinder des Path Tractor aus LS 09 "micha381" an dem sich courseplay natürlich orientiert hat, muss ich mich bedanken.

	Ein dickes Dankeschön auch an Sven777b, der mir die entscheidenen Tipps zum Thema Multiplayerfähigkeit gegeben hat.

	Und last but not least noch ein großes Dankeschön an mein Weibchen die mich in den letzten Wochen diesen "24/7 Wahnsinn" hat ausleben lassen ;)

V. Videos

	Ich habe mir mal die Mühe gemacht und einige Video-Tutorials zu Courseplay zur Verfügung gestellt:

	Einbau:
	http://www.youtube.com/watch?v=frfNX5ZD090

	Steuerung/Überführung
	http://www.youtube.com/watch?v=6ntt2RZGiTA

	Combi Modus
	http://www.youtube.com/watch?v=eQWQ7FrNBO8

	Überladewagen
	http://www.youtube.com/watch?v=DxyInzZgdDc

	Düngemodus
	http://www.youtube.com/watch?v=7yvaOI_TUIg

	Feldmodus
	http://www.youtube.com/watch?v=fHnqo9Jq_nc
