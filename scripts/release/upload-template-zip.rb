#!/usr/bin/env ruby

require "dotenv"
require "octokit"

Dotenv.load

TARGET_TAG = `git tag --points-at HEAD`.strip
if TARGET_TAG.empty?
  puts "no tag"
  exit
else
  puts "search #{TARGET_TAG}"
end

access_token = ENV['GITHUB_ACCESS_TOKEN']
client = Octokit::Client.new( access_token: access_token )

releases = client.releases "bismite/bisdk"
release = releases.select{|r| r.tag_name == TARGET_TAG}.sort_by(&:created_at).first


if release
  puts "#{release.html_url} found."
else
  puts "create release"
  release = client.create_release("bismite/bisdk", TARGET_TAG, draft:true );
end

assets = release.assets

def zip_template(dir,target)
  if File.exist? "#{dir}/#{target}"
    cmd = "(cd #{dir}; zip --quiet --symlinks -r template-#{target}.zip #{target} -x '*/\__MACOSX' -x '*/\.*')"
    puts cmd
    system cmd
  else
    puts "#{dir}/#{target} not exist"
  end
end

%w(
  macos
  linux
  x86_64-w64-mingw32
  emscripten
).each{|target|

  dir = "build/template"
  filename = "template-#{target}.zip"
  zip = "#{dir}/#{filename}"

  if File.exist?(zip)
    if `find #{dir} -newer #{zip}`.empty?
      puts "#{zip} already exist."
    else
      puts "remove #{zip}"
      File.delete(zip)
      zip_template dir, target
    end
  else
    zip_template dir, target
  end

  if assets.find{|a| a.name == filename }
    puts "already uploaded #{filename}"
  else
    if File.exist? zip
      puts "upload #{zip}"
      client.upload_asset release.url, zip
    end
  end
}
