cask "logijuice" do
  version "0.1.2"
  sha256 "ada6e69f57c0f79bda6ae01b2c19f3d5f16a0e40a14814efe9130700a21c5386"

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
