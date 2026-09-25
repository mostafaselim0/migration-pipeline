# Scripts for the client's legacy server

Run these on the client's Oracle Forms / Reports 11g server (the one that has `frmxmltools.jar` and `rwconverter.exe`)
when the client can hand over its ASCON folder.  They convert every `.fmb` to `<name>_fmb.xml` (Forms2XML) and every
`.rdf` to `<name>_RDF.xml` (rwconverter), keeping the folder structure, in parallel, with a log and a retry list.

1. Copy both scripts to the server; edit the SETTINGS block at the top: `$SearchRoot` (the ASCON folder, default
   `C:\ASCON`), `$OutputDir` (default `C:\XML`), the Oracle Home paths, `$MaxThreads`.
2. `powershell -ExecutionPolicy Bypass -File Convert-FMBtoXML.ps1`, then `Convert-RDFtoXML.ps1`.
   Failures are listed in `<OutputDir>\Logs\<date>\*_Failed.txt`; set `$InputListFile` to that file to retry them.
3. Bring back both folders: the ASCON folder -> `clients/<c>/sources/ASCON`, the XML folder -> `clients/<c>/sources/XML`.

Notes: Forms2XML 11.1 ignores its output directory and writes next to the `.fmb`; the script copies the file out and
never overwrites a good XML with a failed one.  rwconverter can crash on reports with a JSP web layout; those are
retried with other JVM options and logged.
