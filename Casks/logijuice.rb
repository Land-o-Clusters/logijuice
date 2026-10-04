cask "logijuice" do
  version "0.1.0"
  sha256 "03748718a367ccf70ab426d608a5d3bccb301fc6fdab7b20cd35efc1291bf14d"

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
