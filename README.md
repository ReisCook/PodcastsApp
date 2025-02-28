# PodcastsApp
iPhone podcasts app


## Setup Instructions

### 1. Add XMLCoder Package
- **Navigate:** File > Add Packages...
- **Search:** `https://github.com/CoreOffice/XMLCoder.git`
- **Add the package.**

### 2. Enable Background Audio Capability
- **Select your project** in the Project Navigator.
- **Choose your app target.**
- **Go to:** Signing & Capabilities.
- **Click:** "+ Capability" and add **Background Modes**.
- **Check:** "Audio, AirPlay, and Picture in Picture".

### 3. Update Info.plist
- **Add key:** `UIBackgroundModes` (Type: Array).
- **Insert item:** `"audio"` into the array.
