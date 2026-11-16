# Release-checklista för eurlc-wgs

Gå igenom uppifrån vid varje release. Ordningen spelar roll: versionsnumret
sätts **innan** valideringen, och efter att en version är validerad och
förseglad ändras ingenting i den (en rättelse blir nästa version).

Versionsnummer: `MAJOR.MINOR.PATCH`, t.ex. `1.0.0`. Rättelser utan nya
funktioner → `1.0.1`. Nya funktioner → `1.1.0`. Ändrade utdata eller
inställningar som kräver omvalidering → nästa MINOR eller MAJOR, och skriv
det i release-texten. För- och testversioner: `1.1.0-beta1`, `1.1.0-rc1`.

---

## 1. Innan koden fryses

- [ ] Det som ska med är klart; det som skjuts upp står i
      `eurlc-wgs-planned.md`.
- [ ] Inga kända fel som påverkar resultat ligger öppna (eller de är
      beskrivna under "Known limitations" i manualen).
- [ ] Dokumentationen är uppdaterad för allt som ändrats:
  - `docs/eurlc-wgs-user-manual.md` (publik)
  - `docs/help.txt` (publik, visas av `--help`)
  - `README.md`
  - `configuration-and-arguments.md`, arkitektur- och planned-dokumenten
    (privata)

## 2. Kod och medföljande filer

- [ ] `perl -wc bin/eurlc-wgs` ger `syntax OK` utan varningar.
- [ ] `bash tests/smoke.sh` — alla kontroller `ok` (argument, config-filer,
      provnamn och lanes, out-mapp, exitkoder, statusfil; under en minut, inga
      verktyg behövs). Lägg till en kontroll när något nytt byggs som kan
      testas utan verktyg.
- [ ] Ingen fil-scope-tilldelning (`my`/`our` med värde) efter huvudprogrammets
      slut — den körs aldrig (BEGIN-fällan). Sök efter nya `our ... = ` långt
      ner i filen.
- [ ] Den inbyggda schemakatalogen (`builtin.json` i skriptet) ändrad sedan
      förra releasen? Höj då `catalog_version`, annars får befintliga
      installationer inte ändringen.
- [ ] `assets/` innehåller allt som ska följa med:
  - `genome_sizes.tsv`
  - `known_databases.tsv` (fyll på med nya kända databasversioner)
  - `known_instruments.tsv` (nya instrumentprefix?)
  - `chewbbaca/filters/...` (t.ex. `chewie_ns_campylobacter/cgmlst_eurl.txt`)
  - rapportens css, logga och favicon
- [ ] `templates/` innehåller de tre rapportmallarna.
- [ ] `.gitignore` fångar Windows-filer (`*Zone.Identifier`), och inga sådana
      är incheckade.

## 3. Conda-miljöer

- [ ] Varje verktyg har sin version låst i sin YML-fil (`paket=version`).
      YML-filerna är den enda versionskällan.
- [ ] Huvudmiljön `envs/core/eurlc-wgs.yml` har låsta versioner.
- [ ] Kanalerna är `conda-forge`, `bioconda`, `nodefaults` i alla filer —
      ingen `defaults`.
- [ ] Alla miljöer går att lösa med strikt kanalprioritet (torrkörning, inget
      installeras):

      ```bash
      for f in envs/*/*.yml; do
        sed '/nodefaults/d' "$f" > /tmp/t.yml
        micromamba create -n t -f /tmp/t.yml --strict-channel-priority \
          --override-channels --dry-run -y > /dev/null 2>&1 \
          && echo "OK   $f" || echo "FAIL $f"
      done
      ```

## 4. Versionsnumret

Sätt det på alla ställen i **ett** commit:

- [ ] `bin/eurlc-wgs`: `$PIPELINE_VERSION` (rad ~20) och `versiondate`
- [ ] `CITATION.cff`: `version` och `date-released` (ÅÅÅÅ-MM-DD)
- [ ] `README.md`: statusrutan (ta bort "beta" för en skarp release)
- [ ] `docs/eurlc-wgs-user-manual.md`: versionsraden överst och
      "This version, ..." i avsnittet Known limitations
- [ ] `eurlc-wgs --version` skriver rätt version.

## 5. Provinstallation på en ren maskin

Helst en dator (eller WSL-instans) utan tidigare eurlc-wgs-miljöer.

- [ ] `bash install.sh` går igenom; `--setup` slutar med "Setup complete"
      och exitkod 0.
- [ ] `bash install.sh --optional` installerar också de avstängda verktygen.
- [ ] `eurlc-wgs --install-efsa-schemas` installerar alla fyra scheman.
- [ ] `eurlc-wgs --help` visar den nya `help.txt` (inte reservtexten).
- [ ] `eurlc-wgs --versions` listar alla verktyg med rätt versioner.

## 6. Testkörningar

Med testdatasetet (minst ett prov per art: Campylobacter, Salmonella,
E. coli, Listeria; gärna ett kontaminerat och ett med för låg täckning).

- [ ] Sekventiellt läge: körningen når slutet, exitkod 0/3/5 som väntat,
      RESULT-raden stämmer.
- [ ] Parallellt läge (`parallel_mode=on`): samma resultat som sekventiellt
      (se `compare` nedan). Titta på `Parallel:`-raden i sammanfattningen.
- [ ] Verifieringsdatasetet (grundsatsen + extra prov) med `reference/`:
      rutan "Verification against ..." i rapporten, eller
      `eurlc-wgs-inspect compare <förra versionens körning> <denna> --out verifiering/`.
      Varje skillnad ska kunna förklaras (nytt verktyg, ny databas, rättat
      fel) och anges med `--expect`; spara `comparison.html` med releasen.
      När versionen godkänts: kopiera dess `eurlc_results_fingerprint.json.gz`
      till `reference/` som ny referens.
- [ ] Parallellt läge jämfört med sekventiellt med `compare`.
- [ ] Valideringsdataseten D1–D3: `report/validation/` visar ALL REQUIRED
      CHECKS AGREE (eller förklarade avvikelser).
- [ ] `--qc-screen` ger trafikljusrapport och `qcscreen_status.json`.
- [ ] `--resume` efter Ctrl+C mitt i en körning: avbrutna steg körs om,
      färdiga återanvänds.
- [ ] `rerun=<steg>` kör om steget och de som beror på det.
- [ ] Rapporten öppnas, länkarna fungerar, även efter att `report/` flyttats
      eller zippats.
- [ ] `log/run_status.json` och `log/events.jsonl` ser rimliga ut.

## 7. Validering och försegling (för den version som ska användas i ackrediterat arbete)

På valideringsdatorn, med exakt den version som releasas:

- [ ] `eurlc-wgs --freeze-databases`
- [ ] `eurlc-wgs --verify-databases` — inga fel; lägg okända versioner i
      `known_databases.tsv` (lokalt, och i `assets/` till nästa release).
- [ ] Valideringen enligt metodbeskrivningen.
- [ ] `eurlc-wgs --generate-seal="<namn>"`, fyll i `created_by` och
      `description` i `config_seal.ini`.
- [ ] En körning visar `SEAL VERIFIED`.
- [ ] Arkivera de fyra filerna (`eurlc-wgs.config`, `db_freeze.config`,
      `conda_manifest.ini`, `config_seal.ini`) under förseglingens namn, och
      notera pipelineversion, git-tagg och (om den finns) DOI.

## 8. Git och GitHub

- [ ] Allt incheckat på `dev`, inga ocommittade ändringar.
- [ ] `dev` sammanfogad till `main`.
- [ ] Tagg: `git tag -a v1.0.0 -m "eurlc-wgs 1.0.0"` och `git push --tags`.
- [ ] GitHub-release från taggen med release-text: nytt, ändrat, rättat,
      kända begränsningar, och om omvalidering eller ny försegling behövs.
- [ ] Om Zenodo är kopplat: kontrollera att releasen fått en DOI, och lägg
      in den i `CITATION.cff` (`doi:`) och i README.

## 9. Efter releasen

- [ ] Sätt nästa utvecklingsversion på `dev`, t.ex. `1.0.1-dev` eller
      `1.1.0-beta1`, så att en testkörning aldrig kan förväxlas med den
      släppta versionen.
- [ ] Meddela användarna (e-post) med länk till release-texten, särskilt om
      något kräver omvalidering.
- [ ] (När bioconda-receptet finns:) uppdatera version och `sha256` i
      receptet och skicka en pull request till bioconda-recipes.
