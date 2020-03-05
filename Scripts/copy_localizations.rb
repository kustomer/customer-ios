# move language keys from web langs.txt into ios' localization files
# adds key_to_append to ios
# ok to run multiple times
require 'json'
require 'awesome_print'


#key_to_append = "globals.upload.component.failure.files.text"

key_to_append = "ui.app.kb.form.builder.options.list.multi.level.list.modal.primary.label.text"
key_to_append_ios_name_override = "derived.okbutton"



bundle_root = "/Users/willjessop/customer-ios-private/Source/Strings.bundle"
bundle = Dir[bundle_root+"/*"]
t = JSON.parse(File.open("/Users/willjessop/Desktop/langs\ 2.txt", "r").read)

ios_lang_strings = bundle.map{|z|z.split("/")[-1].gsub(".lproj","")}
web_lang_strings = t.keys

mismatches = ios_lang_strings - web_lang_strings
direct_matches = ios_lang_strings - mismatches

overrides = {
  "Base"=>"en_us",
  "ur"=>"en_us",
  "zh-Hans"=>"zh_cn",
  "ak"=>"en_us",
  "en"=>"en_us",
  "en-CA"=>"en_us",
  "en-GB"=>"en_us",
  "fr-CA"=>"fr",
  "sr-ME"=>"sr",
  "es-ES"=>"es",
  "zh-Hant"=>"zh_tw",
  "pt-BR"=>"pt_br",
  "en-US"=>"en_us"
}

replacements = {
  "Dateiname" => "fileNames",
  "nomFichier" => "fileNames",
  "филеНамес" => "fileNames",
  "bestandsnamen" => "fileNames",
  "TotalSize" => "totalSize",
  "макСизе" => "maxSize",
  "тоталСизе" => "totalSize"
}

change_dict = {}
ios_langs_that_i_cant_find_a_value_for = []
variables_in_localizations = []

ios_lang_strings.each do |ios|
  web_key = if direct_matches.index(ios)
    ios
  else
    overrides[ios]
  end
  value = t[web_key]&.send("[]",key_to_append)
  if value.nil?
    ios_langs_that_i_cant_find_a_value_for << ios
  else
    replacements.keys.each do |rk|
      value.gsub!("{#{rk}}","{#{replacements[rk]}}")
    end
    change_dict[ios] = value
    variables_in_localizations = (variables_in_localizations + value.scan(/\{([^\}]+)\}/).flatten).uniq
  end
end

ap "variables_in_localizations"
ap variables_in_localizations

if ios_langs_that_i_cant_find_a_value_for.count > 0
  ap ios_langs_that_i_cant_find_a_value_for
  raise "couldnt find matches for above. aborting"
end



ios_lang_strings.each do |ios|
  file = File.open("#{bundle_root}/#{ios}.lproj/Localizable.strings", "r")
  cf = file.read
  file.rewind
  new_line = "\"com.kustomer.#{key_to_append_ios_name_override || key_to_append}\" = \"#{change_dict[ios]}\";"

  if cf.index(new_line).nil?
    File.open("#{bundle_root}/#{ios}.lproj/Localizable.strings", 'a') { |f|
      f << "\n#{new_line}"
    }
    ap "+ Added value to #{ios}"
  else
    ap "   did not add value to #{ios}"
  end
end



