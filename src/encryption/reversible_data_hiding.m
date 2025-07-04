function [stego_image, P_seq_map, F_seq_map] = reversible_data_hiding_embed(cover_image, data_to_embed_bits, steg_params)
% reversible_data_hiding_embed: Embeds data into an image using a PEE-like method.
% This is a simplified implementation based on concepts from the paper (Jia et al., 2019)
% and general PEE principles. Alg.1 in the user's paper has ambiguities.
%
% Args:
%   cover_image (uint8 matrix): Grayscale or color image to embed data into.
%                               If color, embedding is typically done in Luminance channel or one color channel.
%                               For simplicity, this version will use a single channel (e.g., green).
%   data_to_embed_bits (logical vector): Binary data to embed (0s and 1s).
%   steg_params (struct): Parameters for steganography.
%                         - channel_to_embed (int): 1, 2, or 3 for R,G,B. Default 2 (Green).
%                         - pee_threshold (int): Threshold for selecting 'smooth' pixels for PEE.
%                                                Pixels with prediction error |e| < pee_threshold.
%                         - (Future: params for complexity, prediction method from Jia et al.)
%
% Returns:
%   stego_image (uint8 matrix): Image with embedded data.
%   P_seq_map (double matrix): Map of prediction errors (for debugging/analysis).
%   F_seq_map (double matrix): Map of fluctuation values (for debugging/analysis) - Placeholder.

    if nargin < 3
        steg_params.channel_to_embed = 2; % Default to Green channel
        steg_params.pee_threshold = 5;    % Example threshold for PEE
    end
    if ~isfield(steg_params, 'channel_to_embed'), steg_params.channel_to_embed = 2; end
    if ~isfield(steg_params, 'pee_threshold'), steg_params.pee_threshold = 5; end

    if size(cover_image,3) ~= 3
        error('Steganography function currently expects an RGB cover image.');
    end

    stego_image = cover_image;
    channel = steg_params.channel_to_embed;
    work_channel_orig = cover_image(:,:,channel); % Work on one channel

    [rows, cols] = size(work_channel_orig);
    P_seq_map = zeros(rows, cols); % Prediction errors
    F_seq_map = zeros(rows, cols); % Fluctuation values (placeholder for now)

    % --- Simplified PEE: Difference Expansion on pixel pairs or Prediction Error Expansion ---
    % The paper's Alg.1 is complex and refers to Jia et al. (2019) which involves
    % local complexity, fluctuation, prediction error, and histogram shifting.
    % Implementing that fully is a large sub-project.
    % Here, a very basic PEE-like approach is sketched:
    % 1. Predict pixel values.
    % 2. Calculate prediction errors.
    % 3. Expand small errors to embed data.
    % 4. Shift larger errors to maintain reversibility.

    % For simplicity, using a basic predictor: average of left and top neighbors.
    % This is a placeholder for the more complex prediction in Jia et al.

    data_idx = 1;
    num_bits_to_embed = length(data_to_embed_bits);
    embedded_count = 0;

    % Iterate pixels (excluding borders to simplify prediction)
    % A location map is typically used to remember where changes were made.
    % For this simplified version, we modify in place.
    work_channel_modified = double(work_channel_orig);

    for r = 2:rows-1 % Avoid borders for simple prediction
        for c = 2:cols-1
            if data_idx > num_bits_to_embed
                break; % All data embedded
            end

            % 1. Predictor (simple average of left and top)
            predicted_value = round((double(work_channel_orig(r,c-1)) + double(work_channel_orig(r-1,c))) / 2);

            % 2. Prediction Error
            error_val = double(work_channel_orig(r,c)) - predicted_value;
            P_seq_map(r,c) = error_val;

            % 3. Embedding logic (Simplified PEE based on error value)
            % Embed if error is small (e.g., 0 or 1)
            % This is a conceptual sketch. A robust PEE needs careful histogram analysis
            % and management of overflows/underflows.

            % Example: Embed in errors that are 0 or 1
            if error_val == 0 % Expandable error
                new_error = data_to_embed_bits(data_idx); % error becomes 0 or 1
                work_channel_modified(r,c) = predicted_value + new_error;
                data_idx = data_idx + 1;
                embedded_count = embedded_count + 1;
            elseif error_val == 1 && data_idx <= num_bits_to_embed % Also expandable
                new_error = 2 + data_to_embed_bits(data_idx); % error becomes 2 or 3
                work_channel_modified(r,c) = predicted_value + new_error;
                data_idx = data_idx + 1;
                embedded_count = embedded_count + 1;
            elseif error_val > 1 % Shift positive errors
                work_channel_modified(r,c) = work_channel_modified(r,c) + 2; % Shift by capacity (2 bits here)
            elseif error_val == -1 && data_idx <= num_bits_to_embed % Expandable negative error
                new_error = -1 - data_to_embed_bits(data_idx); % error becomes -1 or -2
                work_channel_modified(r,c) = predicted_value + new_error;
                data_idx = data_idx + 1;
                embedded_count = embedded_count + 1;
            elseif error_val < -1 % Shift negative errors
                work_channel_modified(r,c) = work_channel_modified(r,c) - 2; % Shift by capacity
            end

            % Ensure pixel values remain in [0, 255]
            if work_channel_modified(r,c) > 255, work_channel_modified(r,c) = 255; end
            if work_channel_modified(r,c) < 0, work_channel_modified(r,c) = 0; end
        end
        if data_idx > num_bits_to_embed, break; end
    end

    if data_idx <= num_bits_to_embed
        warning('RDH: Not all data bits were embedded. Capacity of this simplified method was exceeded. Embedded %d of %d bits.', embedded_count, num_bits_to_embed);
    else
        fprintf('RDH: Successfully embedded %d bits.\n', embedded_count);
    end

    stego_image(:,:,channel) = uint8(work_channel_modified);

    % F_seq_map is not implemented in this simplified version.
    % The full Jia et al. method would calculate local complexity (Omega_p) and fluctuation (F_Omega).
    % Omega_p = |P1-P4|+|P2-P3|+|P1+P3-P2-P4|+|P3+P4-P1-P2| (P1=above, P2=left, P3=right, P4=below)
    % This would be used to select smoother regions for embedding.
    % The current simplified PEE does not use F_seq_map.
end

function [extracted_data_bits, cover_channel_recovered] = reversible_data_hiding_extract(stego_image_channel, original_dims, num_bits_to_extract, steg_params)
% reversible_data_hiding_extract: Extracts data from a stego image channel.
% Inverse of the simplified PEE implemented in _embed.
%
% Args:
%   stego_image_channel (uint8 matrix): Single channel of the stego image.
%   original_dims (vector): [rows, cols] of the original channel.
%   num_bits_to_extract (int): Number of bits to extract.
%   steg_params (struct): Parameters used during embedding. (esp. pee_threshold if used)
%
% Returns:
%   extracted_data_bits (logical vector): Extracted binary data.
%   cover_channel_recovered (uint8 matrix): Recovered original image channel.

    if nargin < 4
        % steg_params.pee_threshold = 5; % Must match embedding
    end

    work_channel_stego = double(stego_image_channel);
    cover_channel_recovered_double = work_channel_stego; % Start with stego values

    [rows, cols] = deal(original_dims(1), original_dims(2));
    extracted_data_bits = false(1, num_bits_to_extract);
    data_idx = 1;
    extracted_count = 0;

    % Iterate in the same order as embedding
    for r = 2:rows-1
        for c = 2:cols-1
            if data_idx > num_bits_to_extract
                break;
            end

            % Predictor (must be IDENTICAL to embedding)
            % For left neighbor, use the *already recovered* value if available.
            % This requires careful ordering or iterative recovery if dependencies are complex.
            % For this simple predictor (avg of original left and original top),
            % we need to recover pixels in a way that left/top are available.
            % Or, assume predictor uses stego values from non-causal neighborhood (less common for PEE).
            %
            % Simplest for now: predictor uses its own output (recovered values)
            % This means we must process in an order that makes sense.
            % Let's assume for this placeholder that original neighbors are somehow known or estimated
            % For a true reversible scheme, this is critical.
            % A common PEE uses a fixed predictor based on original neighbors or a simple one.
            %
            % To match the simplified embedder, predictor needs original left/top.
            % This implies we need to recover work_channel_orig(r,c-1) and work_channel_orig(r-1,c)
            % before recovering work_channel_orig(r,c). This is a scanline order.

            % predicted_value_rec = round((cover_channel_recovered_double(r,c-1) + cover_channel_recovered_double(r-1,c)) / 2);
            % The above line is problematic because cover_channel_recovered_double(r,c-1) is from current scan,
            % but cover_channel_recovered_double(r-1,c) is from previous scan.
            % Let's use stego image for prediction for simplicity, acknowledging this may not be fully reversible
            % with the current embedder if it modified those predictor pixels.
            % A better approach is to store prediction context or use a fixed predictor.
            % For now, this is a conceptual placeholder for the extraction logic.

            % To be truly reversible with the current simple embed:
            % The embedder used work_channel_orig for prediction.
            % The extractor doesn't have work_channel_orig. This is a common challenge.
            % One solution: embed data in errors e_i = x_i - pred(x_i_stego_neighbors_excluding_causal)
            % Or, the extractor reconstructs using the same logic.
            % Let's assume the predictor for extraction is the same as embedding, using the
            % *current state* of the recovered image for causal neighbors.

            predicted_value_rec = round((cover_channel_recovered_double(r,c-1) + cover_channel_recovered_double(r-1,c)) / 2);

            stego_pixel_val = work_channel_stego(r,c);
            error_val_stego = stego_pixel_val - predicted_value_rec;

            % Extraction logic (inverse of embedding)
            if error_val_stego == 0 % Was error 0, embedded bit 0
                extracted_data_bits(data_idx) = 0;
                cover_channel_recovered_double(r,c) = predicted_value_rec + 0; % Original error was 0
                data_idx = data_idx + 1;
                extracted_count = extracted_count + 1;
            elseif error_val_stego == 1 % Was error 0, embedded bit 1
                extracted_data_bits(data_idx) = 1;
                cover_channel_recovered_double(r,c) = predicted_value_rec + 0; % Original error was 0
                data_idx = data_idx + 1;
                extracted_count = extracted_count + 1;
            elseif error_val_stego == 2 % Was error 1, embedded bit 0
                extracted_data_bits(data_idx) = 0;
                cover_channel_recovered_double(r,c) = predicted_value_rec + 1; % Original error was 1
                data_idx = data_idx + 1;
                extracted_count = extracted_count + 1;
            elseif error_val_stego == 3 % Was error 1, embedded bit 1
                extracted_data_bits(data_idx) = 1;
                cover_channel_recovered_double(r,c) = predicted_value_rec + 1; % Original error was 1
                data_idx = data_idx + 1;
                extracted_count = extracted_count + 1;
            elseif error_val_stego > 3 % Shifted positive error
                cover_channel_recovered_double(r,c) = stego_pixel_val - 2; % Reverse shift
            elseif error_val_stego == -1 % Was error -1, embedded bit 0
                extracted_data_bits(data_idx) = 0;
                cover_channel_recovered_double(r,c) = predicted_value_rec - 1; % Original error was -1
                data_idx = data_idx + 1;
                extracted_count = extracted_count + 1;
            elseif error_val_stego == -2 % Was error -1, embedded bit 1
                extracted_data_bits(data_idx) = 1;
                cover_channel_recovered_double(r,c) = predicted_value_rec - 1; % Original error was -1
                data_idx = data_idx + 1;
                extracted_count = extracted_count + 1;
            elseif error_val_stego < -2 % Shifted negative error
                 cover_channel_recovered_double(r,c) = stego_pixel_val + 2; % Reverse shift
            else
                % This pixel was not used for embedding or shifting (e.g. error was too large, or not -1,0,1)
                % So, its value in stego is its original value relative to its prediction
                cover_channel_recovered_double(r,c) = stego_pixel_val; % No change, already recovered
            end
        end
        if data_idx > num_bits_to_extract, break; end
    end

    if data_idx <= num_bits_to_extract
        warning('RDH Extract: Not all data bits were extracted. Requested %d, found %d.', num_bits_to_extract, extracted_count);
    else
        fprintf('RDH Extract: Successfully extracted %d bits.\n', extracted_count);
    end

    extracted_data_bits = extracted_data_bits(1:extracted_count); % Trim if fewer extracted
    cover_channel_recovered = uint8(round(cover_channel_recovered_double)); % Round and convert back
end


% % Example Usage (Conceptual)
% if 0
%     clc; clearvars; close all;
%     dummy_cover = uint8(randi([0 255], 100, 100, 3));
%     dummy_bits = randi([0 1], 1, 500, 'logical');
%
%     steg_p.channel_to_embed = 1; % Embed in Red
%
%     fprintf('Embedding %d bits...\n', length(dummy_bits));
%     [stego_img_test, p_map, ~] = reversible_data_hiding_embed(dummy_cover, dummy_bits, steg_p);
%
%     fprintf('Extracting bits...\n');
%     [extracted_bits_test, recovered_channel_test] = reversible_data_hiding_extract(stego_img_test(:,:,steg_p.channel_to_embed), ...
%                                                                  [size(dummy_cover,1), size(dummy_cover,2)], ...
%                                                                  length(dummy_bits), ...
%                                                                  steg_p);
%
%     % Check if extracted bits match original (up to the number embedded/extracted)
%     len_compare = min(length(dummy_bits), length(extracted_bits_test));
%     if len_compare > 0
%         match_count = sum(dummy_bits(1:len_compare) == extracted_bits_test(1:len_compare));
%         fprintf('Bit match: %d / %d (%.2f %%)\n', match_count, len_compare, (match_count/len_compare)*100);
%         if match_count == len_compare
%             fprintf('All extracted bits match original embedded bits.\n');
%         else
%             fprintf('Bit mismatch occurred.\n');
%         end
%     else
%         fprintf('No bits were embedded or extracted for comparison.\n');
%     end
%
%     % Check if recovered channel matches original (PSNR)
%     original_channel_test = dummy_cover(:,:,steg_p.channel_to_embed);
%     psnr_rec = psnr(recovered_channel_test, original_channel_test);
%     fprintf('PSNR between original channel and recovered channel: %.2f dB\n', psnr_rec);
%     if psnr_rec > 40 % High PSNR indicates good recovery
%         fprintf('Channel recovery appears successful.\n');
%     else
%         fprintf('Channel recovery may have issues.\n');
%     end
%
%     figure;
%     subplot(1,3,1); imshow(dummy_cover); title('Original');
%     subplot(1,3,2); imshow(stego_img_test); title('Stego Image');
%     recovered_full_img = dummy_cover; recovered_full_img(:,:,steg_p.channel_to_embed) = recovered_channel_test;
%     subplot(1,3,3); imshow(recovered_full_img); title('Recovered Image');
% end
