cask "logijuice" do
  version "0.1.1"
  sha256 "00514f1b9fcca55f2b7fcc095d952f649559ac4ee7f4763369b8148b9d002a65"

  url "https://github.com/Land-o-Clusters/logijuice/releases/download/v#{version}/LogiJuice-#{version}.zip"
  name "LogiJuice"
  desc "Unofficial battery levels and alerts for Logi Bolt receiver devices"
  homepage "https://github.com/Land-o-Clusters/logijuice"

  depends_on macos: :sonoma

  app "LogiJuice.app"
  binary "#{appdir}/LogiJuice.app/Contents/Resources/bin/logijuice"

  uninstall quit: "com.penguinspecz.logijuice"

  zap trash: [
    "~/Library/Application Support/logijuice",
    "~/Library/Group Containers/group.com.penguinspecz.logijuice",
    "~/Library/Preferences/com.penguinspecz.logijuice.plist",
  ]
end
