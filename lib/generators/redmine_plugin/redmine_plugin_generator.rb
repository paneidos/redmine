class RedminePluginGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('../templates', __FILE__)
  
  def generate_plugin
    template 'README.rdoc',          "vendor/plugins/redmine_#{name}/README.rdoc"
    template 'init.rb.erb',          "vendor/plugins/redmine_#{name}/init.rb"
    template 'en_rails_i18n.yml',    "vendor/plugins/redmine_#{name}/config/locales/en.yml"
    template 'test_helper.rb.erb',   "vendor/plugins/redmine_#{name}/test/test_helper.rb"
  end
end
