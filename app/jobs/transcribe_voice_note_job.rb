class TranscribeVoiceNoteJob
  include Sidekiq::Job

  def perform(voice_note_id)
    voice_note = VoiceNote.find(voice_note_id)
    return unless voice_note.audio_file.attached?

    voice_note.audio_file.blob.open do |file|
      audio_format = detect_audio_format(file.path)
      
      if needs_conversion?(audio_format)
        converted_path = Rails.root.join("tmp", "converted_#{SecureRandom.hex(8)}.wav")
        
        begin
          convert_to_wav(file.path, converted_path)
          transcription_file = File.open(converted_path, "rb")
        rescue StandardError => e
          Rails.logger.error("Errore nella conversione audio: #{e.message}")
          return
        end
      else
        transcription_file = file
      end

      begin
        response = OpenAI::Client.new.audio.transcribe(
          parameters: {
            model: "whisper-1",
            file: transcription_file
          }
        )

        if response && response["text"]
          voice_note.update(transcription: response["text"])
        end
      rescue Faraday::BadRequestError => e
        Rails.logger.error("Errore OpenAI: #{e.response[:body]}")
      ensure
        File.delete(converted_path) if defined?(converted_path) && File.exist?(converted_path)
      end
    end
  end

  private

  def detect_audio_format(file_path)
    format_info = `ffprobe -v quiet -print_format json -show_format #{file_path}`
    JSON.parse(format_info)["format"]["format_name"] rescue nil
  end

  def needs_conversion?(format)
    acceptable_formats = ['mp3', 'mp4', 'mpeg', 'mpga', 'm4a', 'wav', 'webm']
    !format.split(',').any? { |f| acceptable_formats.include?(f.strip) }
    
    true
  end

  def convert_to_wav(input_path, output_path)
    system("ffmpeg -i #{input_path} -ar 16000 -ac 1 -c:a pcm_s16le #{output_path}")
  end
end 