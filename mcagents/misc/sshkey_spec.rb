describe 'Sshkey' do

  describe 'generate_key action' do
    it 'generates ssh key' do
    end
    context 'if key already present' do
      it 'refuses to overwrite key'
      context 'if overwrite is enabled' do
        it 'forces key generation'
      end
    end
  end

  describe 'download_key action' do
    it 'downloads ssh key'
    context 'if key not present' do
      it 'fails with error'
    end
  end

  describe 'upload_key action' do
    it 'uploads ssh key'
    context 'if key already present' do
      it 'refuses to overwrite key'
      context 'if overwrite enabled' do
        it 'forces key upload'
      end
    end
  end

  describe 'delete_key action' do
    it 'deletes ssh key'
    context 'if key is not present' do
      it 'does nothing without error'
    end
  end

  describe 'upload_access action' do
    it 'uploads authorized_keys file'
    context 'if file already present' do
      it 'refuses to overwrite file'
      context 'if overwrite is enabled' do
        it 'forces file upload'
      end
    end
  end

  describe 'download_access action' do
    it 'downloads authorized_keys file'
    context 'if no file is present' do
      it 'fails with error'
    end
  end

  describe 'delete_access action' do
    it 'deletes authorized_keys file'
    context 'if no file is present' do
      it 'does nothing without error'
    end
  end

end
