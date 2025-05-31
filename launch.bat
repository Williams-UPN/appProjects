@echo off
flutter emulators --launch Pixel_5
flutter emulators --launch Pixel_6_Pro


supabase db dump -f C:\Users\Williams\Documents\appProjects\supabase\backup_completo.sql