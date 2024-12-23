#!/bin/bash

chmod 777 ./CsvToJson.sh

# Test 1: Test mit einer CSV-Datei
test_csv() {
  echo "Test 1: Test mit einer bereits erstellten CSV-Datei"

  # Führe das Hauptskript mit der CSV-Datei aus
  ./CsvToJson.sh ./testFile.csv
  if [ $? -eq 0 ]; then
    echo "Test 1 erfolgreich: CSV-Datei wurde konvertiert und heruntergeladen."
  else
    echo "Test 1 fehlgeschlagen: Fehler bei der Verarbeitung der großen CSV-Datei."
  fi
}

# Test 2: Test mit einer grossen CSV-Datei
test_large_csv() {
  echo "Test 2: Test mit einer großen CSV-Datei"
  # Erstelle eine grossen CSV-Datei (z.B. 10000 Zeilen)
  CSV_LARGE="/tmp/large_sample.csv"
  echo "Generiere große CSV-Datei..."
  echo "Name,Alter,Beruf,Stadt,Land" > $CSV_LARGE
  for i in {1..10000}; do
    echo "Name$i,Alter$i,Beruf$i,Stadt$i,Land$i" >> $CSV_LARGE
  done

  # Führe das Hauptskript mit der grossen Csv-Datei aus
  ./CsvToJson.sh $CSV_LARGE
  if [ $? -eq 0 ]; then
    echo "Test 2 erfolgreich: Große CSV-Datei wurde k  onvertiert und heruntergeladen."
  else
    echo "Test 2 fehlgeschlagen: Fehler bei der Verarbeitung der großen CSV-Datei."
  fi
}

# Main Test Suite
echo "Starte Test Suite..."
echo ""
echo $(date +"%Y-%m-%d %H:%M:%S")
test_csv
echo ""
echo $(date +"%Y-%m-%d %H:%M:%S")
test_large_csv
echo ""

echo "Test Suite abgeschlossen."
