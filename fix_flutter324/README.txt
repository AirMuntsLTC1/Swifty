Fixes the Flutter 3.27+ APIs so the project builds on CI (Flutter 3.24.3).

In Termux:
  cd ~/NewApp
  python3 ~/storage/downloads/fix_flutter324/fix_flutter324.py
  git add -A && git commit -m "Use Flutter 3.24 APIs" && git push

Then rerun the Build NewApp APK workflow on GitHub.


