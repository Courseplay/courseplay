Courseplay


Dieser Mod befindet sich noch in der Entwicklungsphase und enthält natürlich einige Fehler und noch nicht alle
gedachten Funktionen.
Um diesen Mod im Spiel voll nutzen zu können müsst ihr euch noch bis zum Release gedulden.
Der Mod kann vorerst nur zum Testen genutzt werden.
Der Mod muss erst fertiggestellt und ausgiebig auf Fehler und Funktion getestet werden.

Der Thread "Abfahrhelfer ersatz by netjungle" auf planet-ls.de ist nur für den Austausch der Entwickler und Tester gedacht
um die Entwicklung des Mods und eventuelle Fehler zu besprechen und ist nicht für den Support gedacht. Tauscht euch bei Fragen
und Problemen bezüglich Installation und Funktion bitte außerhalb des Threads mit den anderen Usern aus.
Besser noch, ihr wartet einfach bis zum Release, dann wird sicher ein neuer Thread und eine ausführlich Anleitung
für den Abfahrhelfer erstellt.




Inhaltsverzeichnis

I.   Installationsanweisung
II.  Bedienungsanleitung
III. Entwicklungsstand



I. Installationsanweisung


1. Alle Dateien (außer Readme.txt) mit einem x-beliebigen Zip-Packer packen. Format: *.zip  Name: aacourseplay.zip
2. Das Archiv aacourseplay.zip in das Verzeichnis C:\Users\dein Username\MyGames\FarmingSimulator2011\mods kopieren

3. Jetzt das Archiv des gewünschten Schleppers entpacken und in der moddesc.xml folgende Einträge machen

<vehicleTypes>
        ...
        ...
        ...
        <specialization name="courseplay" />  <<-- Diese Zeile muss eingetragen werden
</vehicleTypes>

anschließend die Dateien wieder zurückpacken.

Das ganze Entpacken und Packen kann man sich mit dem Totalcommander sparen, da er das Entpacken und Packen automatisch macht.
Hier einfach das Archiv öffnen, Datei bearbeiten, speichern, schließen und zurückpacken bestätigen.



II. Bedienungsanleitung


Mode 1: Abfahrer tankt ab und fährt im Rundkurs über die Abladetrigger zum Abladen und wieder zurück zum Startpunkt

1. Den Abfahrer direkt neben das Feld fahren, dann um den Startpunkt zu setzen und Aufzeichnen zu starten die NumPad-Taste
   "9" drücken
2. Gewünschte Strecke abfahren und zurück zum Startpunkt fahren
3. Zurück am Startpunkt nochmal NumPadTaste "9" drücken um die Aufzeichnung zu beenden
4. Wenn ihr nicht mehr als 15 (Spiel)Meter vom Startpunkt entfernt seid könnt ihr mit der NumPad-Taste "7" den Abfahrer
   starten. Seid ihr weiter als 15 Meter erscheint ein Pfeil der euch zum Startpunkt lotst.
6. Um den Abfahrmodus abzubrechen NumPadTaste "7" drücken

Mode 2: Abfahrer wartet am Startpunkt bis er zu 100% beladen ist und fährt dann über die Trigger und wieder zurück

1. Den Abfahrer zum gewünschten Startpunkt fahren, zum Startpunkt setzen und Aufzeichnen NumPad-Taste "9" drücken
2. Gewünschte Strecke abfahren und zürück zum Startpunt fahren
3. Zurück am Startpunkt nochmal NumPad-Taste "9" drücken um die Aufzeichnung zu beenden
4. Wenn ihr nicht mehr als 15 (Spiel)Meter vom Startpunkt entfernt seid könnt ihr mit der NumPad-Taste "7" den Abfahrer
   starten. Seid ihr weiter als 15 Meter erscheint ein Pfeil der euch zum Startpunkt lotst.
6. Um den Abfahrmodus abzubrechen NumPad-Taste "7" drücken

Wartepunkte: hier bleibt der Abfahrer stehen bis ihr ihn wieder weiterschickt

1. Während dem Aufzeichnen einer Route an einem oder mehreren gewünschten Punkten drückt ihr auf dem NumPad die Taste "0"
2. Der Abfahrer hält im Abfahrmodus an den Wartepunkten, um ihn weiterfahren zu lassen NumPad-Taste "7" drücken

Speichern und Laden von Routen:

- Routen speichern könnt ihr mit STRG+S, den Namen der Route mit Enter bestätigen.
- Routen laden geht mit STRG+O, den Cursortasten zur Auswahl und Enter zum bestätigen.



III. Entwicklungsstand


- Modus 1: Abfahrer fährt zum Abtanken neben dem Drescher her - läuft noch nicht richtig und befindet sich noch in Entwicklung
- Modus 2: Abfahrer wartet am Startpunkt bis er voll ist und fährt zum Abladen und wieder zurück - läuft
- Wartepunkte: Abfahrer bleibt an Wartepunkten stehen und kann dann weitergeschickt werden - läuft
- Speichern und Laden von Routen: läuft aber die globalen Tastenbefehle sind noch aktiv und überschneiden sich beim eingeben
  eines Dateinamen
- HUD: noch nicht entwickelt