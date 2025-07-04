function analyze_entropy(original_image_roi_pixels, encrypted_image_roi_pixels)
% analyze_entropy: Calculates information entropy for ROI pixels of
%                  original and encrypted images.
%
% Args:
%   original_image_roi_pixels (cell array): {R, G, B} 1D arrays of uint8 pixel values (original ROI).
%   encrypted_image_roi_pixels (cell array): {R, G, B} 1D arrays of uint8 pixel values (encrypted ROI).
%
% Returns:
%   Prints entropy values to the console.
%   Optionally, can return these values.

    fprintf('Starting Information Entropy Analysis...\n');

    data_sources = {original_image_roi_pixels, encrypted_image_roi_pixels};
    source_names = {'Original ROI', 'Encrypted ROI'};
    channel_names = {'Red Channel', 'Green Channel', 'Blue Channel', 'Combined RGB (as grayscale)'};

    entropy_results = struct();

    for i = 1:length(data_sources)
        current_source_pixels = data_sources{i};
        fprintf('\n--- %s ---\n', source_names{i});
        entropy_results.(matlab.lang.makeValidName(source_names{i})) = struct();

        if isempty(current_source_pixels) || all(cellfun('isempty', current_source_pixels))
            fprintf('Pixel data for "%s" is empty. Skipping entropy calculation.\n', source_names{i});
            continue;
        end

        if ~iscell(current_source_pixels) || length(current_source_pixels) ~= 3
            warning('Expected pixel data as a cell array of 3 channels for %s. Skipping.', source_names{i});
            continue;
        end

        all_channels_combined = []; % For overall grayscale-equivalent entropy

        for channel = 1:3 % R, G, B
            pixel_vector = current_source_pixels{channel};
            if isempty(pixel_vector)
                fprintf('  %s: No data. Entropy: NaN\n', channel_names{channel});
                entropy_results.(matlab.lang.makeValidName(source_names{i})).(matlab.lang.makeValidName(channel_names{channel})) = NaN;
                continue;
            end

            % Ensure pixel_vector is uint8 for entropy calculation expecting 0-255 range
            if ~isa(pixel_vector, 'uint8')
                pixel_vector = uint8(pixel_vector); % Or im2uint8 if scaled double
            end

            ent_val = calculate_single_channel_entropy(pixel_vector);
            fprintf('  %s: %.4f bits/pixel\n', channel_names{channel}, ent_val);
            entropy_results.(matlab.lang.makeValidName(source_names{i})).(matlab.lang.makeValidName(channel_names{channel})) = ent_val;

            all_channels_combined = [all_channels_combined, pixel_vector];
        end

        % Entropy for all ROI pixels treated as a single grayscale sequence
        if ~isempty(all_channels_combined)
            ent_combined_val = calculate_single_channel_entropy(all_channels_combined);
            fprintf('  %s: %.4f bits/pixel\n', channel_names{4}, ent_combined_val);
            entropy_results.(matlab.lang.makeValidName(source_names{i})).(matlab.lang.makeValidName(channel_names{4})) = ent_combined_val;
        else
             fprintf('  %s: No data. Entropy: NaN\n', channel_names{4});
             entropy_results.(matlab.lang.makeValidName(source_names{i})).(matlab.lang.makeValidName(channel_names{4})) = NaN;
        end
    end

    assignin('base', 'entropy_analysis_results', entropy_results);
    fprintf('\nEntropy analysis complete. Results struct stored in workspace variable "entropy_analysis_results".\n');
    fprintf('Ideal entropy for 8-bit data is 8.0 bits/pixel.\n');
end

function H = calculate_single_channel_entropy(pixel_channel_vector)
% Calculates the Shannon entropy for a single channel (1D vector of pixel values).
% Assumes pixel values are uint8 (0-255).

    if isempty(pixel_channel_vector)
        H = NaN;
        return;
    end

    % Calculate histogram (counts for each pixel value 0-255)
    counts = histcounts(pixel_channel_vector, 0:256); % Bins are [0,1), [1,2), ..., [255,256]
                                                      % So edges 0:256 means 256 bins

    % Calculate probability of each pixel value
    probabilities = counts / sum(counts);

    % Remove zero probabilities to avoid log(0)
    probabilities = probabilities(probabilities > 0);

    % Calculate entropy: H = -sum(p * log2(p))
    H = -sum(probabilities .* log2(probabilities));
end


% % Example Usage:
% if 0
%     clc; clearvars; close all;
%     % Dummy ROI pixel data (similar to analyze_histogram example)
%     % Original ROI (less random)
%     orig_r = uint8(randi([60, 90], 1, 2000));
%     orig_g = uint8(randi([100, 130], 1, 2000));
%     orig_b = uint8(randi([140, 170], 1, 2000));
%     original_data_entropy = {orig_r, orig_g, orig_b};
%
%     % Encrypted ROI (should be more random, higher entropy)
%     enc_r = uint8(randi([0, 255], 1, 2000));
%     enc_g = uint8(randi([0, 255], 1, 2000));
%     enc_b = uint8(randi([0, 255], 1, 2000));
%     encrypted_data_entropy = {enc_r, enc_g, enc_b};
%
%     analyze_entropy(original_data_entropy, encrypted_data_entropy);
%
%     % Expected output:
%     % Original ROI entropies should be lower than encrypted ROI entropies.
%     % Encrypted ROI entropies should be close to 8.0 for good encryption.
%
%     % Test with a constant image (entropy should be 0)
%     const_r = uint8(ones(1,1000) * 50);
%     const_g = uint8(ones(1,1000) * 50);
%     const_b = uint8(ones(1,1000) * 50);
%     constant_data = {const_r, const_g, const_b};
%     fprintf('\n--- Constant Data Test ---\n');
%     analyze_entropy(constant_data, []); % Only analyze one set
%     % Expected: Entropy close to 0 for constant data.
%
%     % Test with helper function from analyze_histogram.m (if available on path)
%     % This requires analyze_histogram.m to be on the path and contain get_roi_pixels_from_image
%     % if exist('get_roi_pixels_from_image','file') && exist('peppers.png','file')
%     %     img_peppers = imread('peppers.png');
%     %     [h_pep, w_pep, ~] = size(img_peppers);
%     %     roi_info_pep(1).patch_index = 1;
%     %     roi_info_pep(1).has_roi = true;
%     %     roi_info_pep(1).roi_rect = [1,1,w_pep,h_pep]; % Full image as ROI
%     %     idx_shuffled_pep = [1];
%     %
%     %     peppers_pixels = get_roi_pixels_from_image(img_peppers, roi_info_pep, idx_shuffled_pep);
%     %     fprintf('\n--- Peppers Image Full ROI Entropy Test ---\n');
%     %     analyze_entropy(peppers_pixels, []);
%     % else
%     %     fprintf('\nSkipping peppers test as get_roi_pixels_from_image or peppers.png not found.\n');
%     % end
%
% end
