# Weatherspoon

A macOS menu bar app to display current weather information based on your location or a specified city.

## Features

- Shows current weather in the menu bar with emoji
- Uses your current location or a specified city name
- Displays detailed weather information including temperature, feels like, humidity, and chance of rain
- Shows a 3-day forecast
- Configurable update interval
- Opens detailed weather info in browser when clicked

## Building and Installing

### Requirements

- macOS 10.15 or later
- Swift 5.3 or later

### Build Instructions

1. Clone the repository
2. Run the build script:

```bash
cd /path/to/Weatherspoon
./build.sh
```

3. To install to the Applications folder:

```bash
./build.sh --install
```

## Usage

Once installed, launch the app from the Applications folder. It will appear as a weather emoji with the current temperature in your menu bar.

Click on the menu bar icon to view detailed weather information and access settings.

### Settings

- **Set City**: Specify a city name for weather information if location services are unavailable
- **Update Interval**: Choose how often to update the weather (30 minutes, 1 hour, 2 hours, or 4 hours)
- **Refresh Now**: Manually refresh the weather data

## Credits

- Weather data provided by [wttr.in](https://wttr.in)
- Based on the Hammerspoon Weather.spoon by James Turnbull

## Versioning and Releases

Weatherspoon follows [Semantic Versioning](https://semver.org/) (MAJOR.MINOR.PATCH).

### Version Information
- Current version is stored in the `VERSION` file and in `Resources/Info.plist`
- Version format: `v1.0.0` (for tags and releases)

### Release Process
1. Update version in `VERSION` file and `Resources/Info.plist` (both `CFBundleVersion` and `CFBundleShortVersionString`)
2. Commit changes: `git commit -am "Bump version to x.y.z"`
3. Push changes: `git push origin main` (or your default branch)
4. Create and push a new tag: `git tag vx.y.z && git push origin vx.y.z`
5. GitHub Actions will automatically build the app and create a new release with both source code and app attached

You can use the provided `create_initial_release.sh` script to create the initial v1.0.0 release:
```bash
chmod +x ./create_initial_release.sh
./create_initial_release.sh
```

## License

MIT
