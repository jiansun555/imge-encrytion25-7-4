function saliency_map_binary = detect_saliency(image_path, method, threshold)
% detect_saliency: Detects salient regions in an image.
%
% Args:
%   image_path (str): Path to the input image.
%   method (str): Saliency detection method. Options: 'GBVS', 'FT', 'SR', 'LC', 'HC', 'AC', 'MSS' or 'DeepLearningPlaceholder'.
%                 Default is 'GBVS'.
%   threshold (float): Threshold to binarize the saliency map.
%                      If 'auto', uses Otsu's method. Default is 'auto'.
%
% Returns:
%   saliency_map_binary (logical matrix): Binary saliency map of the same size as the input image.
%
% Notes:
%   This function provides a placeholder for deep learning methods and implements
%   several classic saliency algorithms.
%   For 'GBVS' and other non-Matlab-native methods, external toolboxes would be required.
%   Here, we will implement a simple classic method if 'GBVS' is not available,
%   or use what's available in Image Processing Toolbox.
%   The paper mentions EDN-lite (MobileNetV2 based). True reproduction of this
%   would require Deep Learning Toolbox and a pre-trained model or training.
%   As per discussion, a simpler alternative is acceptable.
%   We will use a readily available classical method, e.g., spectral residual.

    if nargin < 3 || isempty(threshold)
        threshold = 'auto';
    end
    if nargin < 2 || isempty(method)
        method = 'SR'; % Default to Spectral Residual as it's often effective and simple.
    end

    % Read image
    try
        img = imread(image_path);
    catch ME
        error('Failed to read image at path: %s. Error: %s', image_path, ME.message);
    end

    if size(img, 3) == 1
        % Grayscale image, replicate to 3 channels for consistency if needed by some methods
        % img = repmat(img, [1, 1, 3]);
        img_gray = img;
    else
        img_gray = rgb2gray(img);
    end

    img_double = im2double(img_gray);

    saliency_map_gray = [];

    switch upper(method)
        case 'DEEPLEARNINGPLACEHOLDER'
            % This is where a call to a pre-trained deep learning model would go.
            % e.g., saliency_map_gray = predict(my_sod_model, img);
            % For now, as a placeholder, we'll fall back to a classical method.
            warning('Deep Learning SOD model not implemented/available. Falling back to Spectral Residual (SR).');
            saliency_map_gray = spectral_residual_saliency(img_double);

        case 'SR' % Spectral Residual Saliency (Hou & Zhang, 2007)
            saliency_map_gray = spectral_residual_saliency(img_double);

        case 'FT' % Frequency-Tuned Saliency (Achanta et al., 2009) - needs color image
            if size(img, 3) == 3
                img_lab = rgb2lab(im2double(img));
                saliency_map_gray = frequency_tuned_saliency(img_lab);
            else
                warning('FT method prefers color images. Using grayscale SR instead.');
                saliency_map_gray = spectral_residual_saliency(img_double);
            end

        % Add more cases for other classical methods if needed and feasible:
        % 'LC' - Luminance Contrast
        % 'HC' - Histogram-based Contrast
        % 'AC' - Average Contrast
        % 'GBVS' - Graph-Based Visual Saliency (typically requires external toolbox)
        %   if exist('gbvs', 'file')
        %       saliency_map_gray = gbvs(img);
        %       if isstruct(saliency_map_gray) % gbvs might return a struct
        %           saliency_map_gray = saliency_map_gray.master_map_resized;
        %       end
        %   else
        %       warning('GBVS method not found. Falling back to Spectral Residual (SR).');
        %       saliency_map_gray = spectral_residual_saliency(img_double);
        %   end

        otherwise
            warning('Unknown saliency method: %s. Using Spectral Residual (SR).', method);
            saliency_map_gray = spectral_residual_saliency(img_double);
    end

    if isempty(saliency_map_gray)
        error('Saliency map could not be computed.');
    end

    % Normalize saliency map to [0, 1]
    if max(saliency_map_gray(:)) > min(saliency_map_gray(:))
        saliency_map_gray = (saliency_map_gray - min(saliency_map_gray(:))) / ...
                            (max(saliency_map_gray(:)) - min(saliency_map_gray(:)));
    else
        saliency_map_gray = zeros(size(saliency_map_gray)); % Avoid NaN if map is flat
    end

    % Binarize the saliency map
    if strcmp(threshold, 'auto')
        binary_threshold = graythresh(saliency_map_gray); % Otsu's method
    elseif isnumeric(threshold) && threshold >= 0 && threshold <= 1
        binary_threshold = threshold;
    else
        warning('Invalid threshold value. Using Otsu''s method.');
        binary_threshold = graythresh(saliency_map_gray);
    end

    saliency_map_binary = imbinarize(saliency_map_gray, binary_threshold);

end

% --- Helper function for Spectral Residual Saliency ---
function smap = spectral_residual_saliency(img_gray_double)
% Computes saliency map using the Spectral Residual method.
% Input: grayscale image (double type, range [0,1])

    % Ensure input is 2D
    if size(img_gray_double, 3) > 1
        error('Spectral Residual requires a grayscale image.');
    end

    % FFT
    myFFT = fft2(img_gray_double);
    myLogAmplitude = log(abs(myFFT) + eps); % Add eps to avoid log(0)
    myPhase = angle(myFFT);

    % Average filter in log-spectral domain (approximating local average)
    % A common filter size is 3x3 or 5x5. For simplicity, using a predefined one.
    h = fspecial('average', [3 3]);
    mySmooth = imfilter(myLogAmplitude, h, 'replicate');

    % Spectral Residual
    mySpectralResidual = myLogAmplitude - mySmooth;

    % Inverse FFT to get the saliency map in spatial domain
    smap = abs(ifft2(exp(mySpectralResidual + 1i*myPhase))).^2;

    % Post-processing: Gaussian filter to make it more blob-like
    smap = imfilter(smap, fspecial('gaussian', [5 5], 2.5), 'replicate');

    % Normalize (done in main function)
end

% --- Helper function for Frequency-Tuned Saliency (simplified) ---
function smap = frequency_tuned_saliency(img_lab)
% Computes saliency map using a simplified Frequency-Tuned approach.
% Input: LAB image (double type)

    L = img_lab(:,:,1);
    a = img_lab(:,:,2);
    b = img_lab(:,:,3);

    % Mean LAB values
    meanL = mean(L(:));
    meana = mean(a(:));
    meanb = mean(b(:));

    % Saliency is the Euclidean distance in LAB space from the mean LAB value
    % This is a very simplified interpretation of "Frequency-Tuned" which
    % often involves DoG filtering. Here, we use global color contrast.
    smap = sqrt((L - meanL).^2 + (a - meana).^2 + (b - meanb).^2);

    % Normalize (done in main function)
end


% % Example Usage
% if 0 % Set to 1 to run example
%     clc; clearvars; close all;
%
%     % Create a dummy image or use a standard Matlab image
%     % test_img_path = 'peppers.png'; % Requires Image Processing Toolbox
%     % If 'peppers.png' is not available, create a simple one:
%     if exist('peppers.png', 'file')
%         test_img_path = 'peppers.png';
%     else
%         fprintf('peppers.png not found. Creating a dummy image for testing.\n');
%         dummy_img = zeros(128, 128, 3, 'uint8');
%         dummy_img(32:96, 32:96, 1) = 255; % Red square
%         dummy_img(48:80, 48:80, 2) = 255; % Green on top
%         imwrite(dummy_img, 'dummy_test_image.png');
%         test_img_path = 'dummy_test_image.png';
%     end
%
%     fprintf('Testing Saliency Detection...\n');
%
%     % Test with Spectral Residual
%     try
%         smap_sr_bin = detect_saliency(test_img_path, 'SR', 'auto');
%         smap_sr_gray = spectral_residual_saliency(im2double(rgb2gray(imread(test_img_path))));
%         smap_sr_gray_norm = (smap_sr_gray - min(smap_sr_gray(:))) / (max(smap_sr_gray(:)) - min(smap_sr_gray(:)));
%
%
%         figure('Name', 'Saliency Detection Test - SR');
%         subplot(1,3,1); imshow(imread(test_img_path)); title('Original Image');
%         subplot(1,3,2); imshow(smap_sr_gray_norm); title('Saliency Map (SR - Grayscale)');
%         subplot(1,3,3); imshow(smap_sr_bin); title('Binary Saliency Map (SR)');
%         fprintf('Spectral Residual Saliency test complete.\n');
%     catch ME
%         fprintf('Error in SR Saliency test: %s\n', ME.message);
%     end
%
%     % Test with Frequency-Tuned (simplified)
%     try
%         original_img_color = imread(test_img_path);
%         if size(original_img_color,3) < 3
%             original_img_color = repmat(original_img_color, [1 1 3]); % ensure color
%             imwrite(original_img_color, test_img_path); % overwrite if it was gray
%         end
%
%         smap_ft_bin = detect_saliency(test_img_path, 'FT', 0.5); % Using a fixed threshold
%         smap_ft_gray = frequency_tuned_saliency(rgb2lab(im2double(imread(test_img_path))));
%         smap_ft_gray_norm = (smap_ft_gray - min(smap_ft_gray(:))) / (max(smap_ft_gray(:)) - min(smap_ft_gray(:)));
%
%         figure('Name', 'Saliency Detection Test - FT (Simplified)');
%         subplot(1,3,1); imshow(imread(test_img_path)); title('Original Image');
%         subplot(1,3,2); imshow(smap_ft_gray_norm); title('Saliency Map (FT - Grayscale)');
%         subplot(1,3,3); imshow(smap_ft_bin); title('Binary Saliency Map (FT)');
%         fprintf('Frequency-Tuned (Simplified) Saliency test complete.\n');
%     catch ME
%         fprintf('Error in FT Saliency test: %s\n', ME.message);
%     end
%
%     if strcmp(test_img_path, 'dummy_test_image.png')
%         delete(test_img_path); % Clean up dummy image
%     end
% end
