# USB-Uncensored-LLM ⚡

**USB-Uncensored-LLM** è un ambiente AI locale portatile, completamente air-gapped e zero-dipendenze, progettato per funzionare direttamente dal tuo **disco locale** o da una **chiavetta USB/SSD**. Bypassa installazioni complesse eseguendo modelli linguistici di grandi dimensioni nativamente sul tuo hardware, senza bisogno di internet.

Con un'architettura unificata, puoi inizializzare i tuoi modelli AI una volta sola e portarli con te su Windows, macOS e Linux.

🎥 **Guarda il video di Setup & Demo:** [https://youtu.be/60PSXsoXc8A](https://youtu.be/60PSXsoXc8A)

[![USB-Uncensored-LLM Setup & Demo](https://img.youtube.com/vi/60PSXsoXc8A/maxresdefault.jpg)](https://youtu.be/60PSXsoXc8A)

## 🚀 Caratteristiche Principali
* **Zero Dipendenze:** Include Python portatile e binari del motore isolati. Nessun permesso di sistema, modifica al registro o gestori di pacchetti richiesti.
* **Interoperabilità Cross-Platform:** Usa un sistema intelligente di volume `Shared`: scarica i tuoi modelli AI da 5GB+ *una volta sola* e usali nativamente su Windows, macOS e Linux senza duplicazioni.
* **Senza Censura:** Integra modelli fine-tuned ablative e heretic all'avanguardia per interazioni completamente senza filtri.
* **Interfaccia Web Proxyata:** Il server HTTP Python personalizzato serve istantaneamente un'interfaccia dark mode velocissima. Puoi accedere all'AI dal tuo telefono o tablet sulla stessa rete WiFi senza complesse configurazioni CORS.
* **Accelerazione Hardware:** Usa un motore Ollama compilato personalizzato sotto il cofano, sfruttando nativamente istruzioni CPU AVX, NVIDIA CUDA o Apple Metal GPU a seconda della macchina host.

---

## 💻 Requisiti di Sistema
Prima di preparare la tua unità, assicurati di avere:
- **Archiviazione:** Una chiavetta USB 3.0+ o SSD con un minimo assoluto di **8 GB** di spazio libero (16 GB sono **altamente raccomandati**).
- **RAM:** Il computer host dovrebbe avere almeno **8 GB di memoria** per eseguire i modelli 2B/4B, e **16 GB di memoria** per eseguire fluentemente i modelli 9B/12B.

---

## 📂 Architettura delle Cartelle

Il progetto è strutturato per isolare strettamente gli eseguibili del sistema operativo mentre unifica in modo sicuro i pesi dei modelli per risparmiare preziosa capacità di archiviazione portatile.

```text
[Unità USB Portatile]
 ├── 📁 Android    # Installer e launcher nativi Android (Termux)
 ├── 📁 Linux      # Installer e launcher offline Ubuntu/Debian
 ├── 📁 Mac        # Installer e launcher offline macOS
 ├── 📁 Windows    # Menu automatici Windows offline
 └── 📁 Shared     # Sistema Dati Unificato
      ├── 📁 bin         (Eseguibili isolati: ollama-windows.exe, ollama-darwin...)
      ├── 📁 chat_data   (Cronologia conversazioni persistente cross-platform)
      ├── 📁 models      (Pesi GGUF HuggingFace e database locale)
      └── 📁 python      (Ambiente Python portatile isolato)
```

---

## 🧠 Libreria Modelli AI Curata

Questa USB include un installer curato per i migliori modelli locali senza censura disponibili sul mercato open-source:

1. **Gemma 2 2B Abliterated (~1.6 GB)**: *Raccomandato per tutti.* Estremamente veloce, incredibilmente intelligente per la sua dimensione, con vettori di allineamento alla sicurezza matematicamente rimossi.
2. **Gemma 4 E4B Ultra Uncensored Heretic (~5.34 GB)**: Un fine-tune "heretic" che forza aggressivamente la risposta a tutte le richieste dell'utente indipendentemente da contenuto o legalità.
3. **Qwen 3.5 9B Uncensored Aggressive (~5.2 GB)**: Un modello di ragionamento molto più grande, incredibilmente competente con una stretta aderenza a risposte grezze e imparziali.
4. **Modelli Personalizzati**: L'installer supporta il download di qualsiasi peso `.gguf` direttamente da HuggingFace nativamente nel motore USB.

---

## ⚙️ Guida Rapida

### Passo 1: Inizializza il Motore
A seconda del computer in cui sei collegato, naviga nella cartella del rispettivo Sistema Operativo ed esegui lo script di installazione.
* **Windows:** Fai doppio clic su `Windows/install.bat`
* **macOS:** Apri Terminale, trascina `Mac/install.command` e premi Invio.
* **Linux:** Esegui `bash Linux/install.sh`
* **Android:** Apri Termux, esegui `bash Android/install.sh`

> **Nota:** Inizializzare scarica semplicemente il piccolo motore di esecuzione da 50MB specifico per quel computer nella cartella `Shared/bin`.

### Passo 2: Scarica i Modelli AI
È altamente raccomandato eseguire la fase di download dei modelli tramite un **PC Windows** (`Windows/install.bat`), che fornisce un catalogo interattivo basato su terminale per selezionare e scaricare facilmente modelli GGUF senza censura accuratamente curati.
*(Se non hai un PC Windows, scarica semplicemente i tuoi pesi `.gguf` da HuggingFace e inseriscili manualmente nella cartella `Shared/models`).*

### Passo 3: Avvia
Apri la cartella del rispettivo OS ed esegui lo script di avvio:
* **Windows:** `Windows/start-fast-chat.bat`
* **macOS:** `Mac/start.command`
* **Linux:** `bash Linux/start.sh`
* **Android:** `bash Android/start.sh` (in Termux)

Il motore si avvierà in background e il tuo browser web predefinito si aprirà automaticamente sull'interfaccia Chat servita localmente.

---

## 🏠 Installazione su Disco Locale
Anche se questo progetto è ottimizzato per la portabilità USB, funziona perfettamente come configurazione AI locale leggera sul tuo computer principale.

**Come Installare Localmente:**
1.  **Scarica/Clona** questo repository in una cartella sul tuo disco `C:\` o `D:\`.
2.  Naviga nella cartella **Windows** (o Mac/Linux).
3.  Esegui **`install.bat`** e scegli i tuoi modelli desiderati.
4.  Il sistema scaricherà tutto in quella cartella locale.
5.  Esegui **`start-fast-chat.bat`** per iniziare.

*Vantaggio:* Eseguire da un SSD interno è significativamente più veloce che da una USB, risultando in un caricamento dei modelli AI quasi istantaneo!

---

## 📱 Android Nativo (Termux)
Esegui il motore AI **direttamente sul tuo telefono o tablet Android** — nessun PC necessario!

### Requisiti
- **Termux** installato da [F-Droid](https://f-droid.org/en/packages/com.termux/) (NON dal Play Store — è obsoleto)
- **6 GB+ di RAM** (8 GB+ raccomandati). Solo il modello 2B funziona bene su dispositivi con 6 GB.
- **WiFi o dati mobili** per la configurazione iniziale (download del motore + modelli)
- **Processore ARM64** (praticamente tutti i telefoni/tablet Android moderni)

### Configurazione
1. Copia la cartella USB-Uncensored-LLM sul tuo dispositivo Android (tramite USB OTG, trasferimento file o `git clone`)
2. Apri **Termux** e naviga nella cartella del progetto
3. Esegui: `bash Android/install.sh`
4. Seleziona il tuo modello (Gemma 2 2B raccomandato per la maggior parte dei dispositivi Android)
5. Attendi il completamento dei download — **mantieni Termux in primo piano!**

### Avvio
```bash
bash Android/start.sh
```
Il motore AI si avvia e Chrome si apre automaticamente con l'interfaccia Chat.

### Consigli Performance Android
- **Esegui `termux-wake-lock`** prima di iniziare — impedisce ad Android di uccidere il processo
- **Mantieni Termux in primo piano** per le migliori prestazioni
- **Chiudi altre app** per liberare RAM per il modello AI
- **Usa il modello 2B** su dispositivi con meno di 12 GB di RAM
- **Collega il caricabatterie** — l'inferenza LLM consuma la batteria velocemente
- Aspettati **~3-10 token/sec** sul modello 2B (contro 30-50+ su un PC con GPU)

---

## 📱 Accesso Mobile in LAN
Se vuoi usare l'AI pesante dal tuo telefono mentre sei sul divano:
1. Assicurati che il PC che esegue lo script `start` e il tuo telefono siano sulla **stessa rete WiFi**.
2. Il terminale rileverà automaticamente il tuo host e mostrerà un indirizzo IP di **Accesso di Rete** (es. `http://192.168.1.15:3333`).
3. Basta digitare quell'URL nel browser mobile (Safari/Chrome). Il server Python personalizzato instrada perfettamente le query mobili direttamente alla USB! *(Nota: Se le pagine non si caricano, assicurati che il Firewall di Windows permetta connessioni in entrata sulla porta `3333`)*.

---

## 🛠️ Risoluzione Problemi

- **Lo script si chiude istantaneamente su Windows:** Probabilmente hai gli alias di esecuzione delle app Windows legacy attivi, che ingannano il sistema. Esegui lo script tramite un prompt dei comandi, o fai clic destro sul file `.bat` ed esegui "Come Amministratore".
- **"Motore Ollama Non Trovato":** Hai tentato di eseguire lo script `start` prima che lo script `install` scaricasse il software di base per il tuo sistema operativo specifico. Esegui l'installer del tuo OS!
- **Generazione Lenta:** Il tuo modello è troppo grande per la RAM del tuo PC host. Riesegui `install.bat` e seleziona il modello **Gemma 2 2B Abliterated**, che funziona rapidamente anche su macchine meno recenti.

---
> *Disclaimer: USB-Uncensored-LLM è costruito per la libertà di calcolo senza compromessi. Utilizzando modelli ablativo, il sistema non moralizzerà, farà lezioni o rifiuterà i tuoi prompt. Si prega di utilizzare responsabilmente.*
