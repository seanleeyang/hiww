import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ConfirmDialog } from './ConfirmDialog';
import { ApiError } from '../api/client';

describe('ConfirmDialog', () => {
  it('renders nothing when closed', () => {
    const { container } = render(
      <ConfirmDialog open={false} title="Cancel this order" onConfirm={vi.fn()} onClose={vi.fn()} />
    );
    expect(container).toBeEmptyDOMElement();
  });

  it('disables confirm until the reason meets the minimum length', async () => {
    const user = userEvent.setup();
    const onConfirm = vi.fn().mockResolvedValue(undefined);
    render(
      <ConfirmDialog
        open
        title="Cancel this order"
        reason={{ label: 'Reason', minLength: 10 }}
        confirmLabel="Cancel order"
        onConfirm={onConfirm}
        onClose={vi.fn()}
      />
    );

    const confirmButton = screen.getByRole('button', { name: 'Cancel order' });
    expect(confirmButton).toBeDisabled();

    await user.type(screen.getByRole('textbox'), 'too short');
    expect(confirmButton).toBeDisabled();

    await user.type(screen.getByRole('textbox'), ' — now long enough');
    expect(confirmButton).toBeEnabled();

    await user.click(confirmButton);
    expect(onConfirm).toHaveBeenCalledWith('too short — now long enough');
  });

  it('surfaces an error and stays open when onConfirm rejects', async () => {
    const user = userEvent.setup();
    const onConfirm = vi.fn().mockRejectedValue(new ApiError('order already cancelled', 409, 'INVALID_STATUS'));
    const onClose = vi.fn();
    render(
      <ConfirmDialog open title="Confirm payment" confirmLabel="Confirm" onConfirm={onConfirm} onClose={onClose} />
    );

    await user.click(screen.getByRole('button', { name: 'Confirm' }));

    expect(await screen.findByText('order already cancelled')).toBeInTheDocument();
    expect(onClose).not.toHaveBeenCalled();
  });

  it('closes on Escape', async () => {
    const user = userEvent.setup();
    const onClose = vi.fn();
    render(<ConfirmDialog open title="Cancel this order" confirmLabel="Cancel order" onConfirm={vi.fn()} onClose={onClose} />);

    await user.keyboard('{Escape}');
    expect(onClose).toHaveBeenCalled();
  });

  it('shows how many more characters the reason needs, and clears the hint once it is long enough', async () => {
    const user = userEvent.setup();
    render(
      <ConfirmDialog
        open
        title="Cancel this order"
        reason={{ label: 'Reason', minLength: 10 }}
        confirmLabel="Cancel order"
        onConfirm={vi.fn()}
        onClose={vi.fn()}
      />
    );

    expect(screen.getByText('10 more characters needed')).toBeInTheDocument();
    await user.type(screen.getByRole('textbox'), 'long enough reason');
    expect(screen.getByText('Looks good')).toBeInTheDocument();
  });

  it('renders as an accessible dialog', () => {
    render(<ConfirmDialog open title="Cancel this order" confirmLabel="Cancel order" onConfirm={vi.fn()} onClose={vi.fn()} />);
    expect(screen.getByRole('dialog', { name: 'Cancel this order' })).toBeInTheDocument();
  });
});
