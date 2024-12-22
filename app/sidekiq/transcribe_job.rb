class TranscribeJob
  include Sidekiq::Job

  attr_accessor :tmp_dir, :voice_note

  def perform(voice_note)

    @voice_note = voice_note
    @tmp_dir = Dir.mktmpdir 

    download
  ensure
    FileUtils.remove_entry tmp_dir
  end

  def download
    system "wget -0 #{input_path} #{video.download_url}"
  end

  def input_path
    "#{tmp_dir}/#{voice_note.id}"
  end



end
