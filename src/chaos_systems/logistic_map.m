function x_out = logistic_map(x0, lambda, num_iterations, discard_transients)
% logistic_map: Generates a chaotic sequence using the Logistic map.
%
% Args:
%   x0: Initial value for x.
%   lambda: Parameter of the Logistic map.
%   num_iterations: Total number of iterations to generate after discarding transients.
%   discard_transients: Number of initial iterations to discard. (Optional, default 1000)
%
% Returns:
%   x_out: Generated chaotic sequence (row vector).
%
% Equation: Xn+1 = λ * Xn * (1 - Xn)

    if nargin < 4
        discard_transients = 1000; % Default number of transients to discard
    end
    if nargin < 3
        error('logistic_map requires at least 3 arguments: x0, lambda, num_iterations');
    end

    if x0 < 0 || x0 > 1
        warning('logistic_map: Initial value x0 is typically within [0,1]. Value provided: %f', x0);
    end
    if lambda < 0 || lambda > 4
        warning('logistic_map: Lambda parameter is typically within [0,4]. Value provided: %f', lambda);
    end

    total_points_to_generate = num_iterations + discard_transients;

    x_all = zeros(1, total_points_to_generate);
    x_i = x0;

    for k = 1:total_points_to_generate
        x_next = lambda * x_i * (1 - x_i);
        x_all(k) = x_next;
        x_i = x_next;
    end

    % Discard transients
    if discard_transients >= total_points_to_generate && num_iterations > 0
        warning('LogisticMap: discard_transients (%d) is >= total points generated (%d). Returning empty sequence.', discard_transients, total_points_to_generate);
        x_out = [];
    elseif num_iterations == 0 % If only transients are requested
        x_out = x_all(1:discard_transients);
    else
        start_index = discard_transients + 1;
        if start_index > total_points_to_generate
            x_out = []; % Not enough points generated
        else
            x_out = x_all(start_index : end);
        end
    end

    % Ensure output is a row vector
    x_out = reshape(x_out, 1, []);
end

% % Example Usage (can be commented out or moved to a test script `test_logistic.m`)
% if 0 % Set to 1 to run example
%     clc; clearvars; close all;
%
%     x0_test = 0.5;
%     lambda_test = 4.0;
%     num_iter_test = 1000;
%     discard_trans_test = 100;
%
%     x_sequence = logistic_map(x0_test, lambda_test, num_iter_test, discard_trans_test);
%
%     if isempty(x_sequence)
%         fprintf('Logistic map returned empty sequence.\n');
%         return;
%     end
%
%     disp(['Generated ', num2str(length(x_sequence)), ' points after transients.']);
%
%     figure('Name', 'Logistic Map Sequence');
%     plot(x_sequence, '.-');
%     title(['Logistic Map: x0=', num2str(x0_test), ', \lambda=', num2str(lambda_test)]);
%     xlabel('Iteration');
%     ylabel('x_n');
%     grid on;
%
%     % Test histogram for uniformity (expected for lambda=4)
%     figure('Name', 'Logistic Map Histogram');
%     histogram(x_sequence, 50);
%     title(['Histogram of Logistic Map Sequence (\lambda=', num2str(lambda_test), ')']);
%     xlabel('x_n value');
%     ylabel('Frequency');
%     grid on;
% end
