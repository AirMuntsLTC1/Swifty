Location: tap the field and it fills with your place (asks permission first).

Apply in Termux:
  unzip -o ~/storage/downloads/swifs_location_fix.zip -d ~/NewApp
  cd ~/NewApp && git add -A && git commit -m 'Auto location in profile edit' && git push

The build will download the new packages (geolocator, geocoding) automatically.
