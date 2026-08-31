import { describe, it, expect, vi } from 'vitest';
import { fireEvent, render, screen } from '@testing-library/react';
import { PostsPager } from './PostsPager';

describe('PostsPager', () => {
  it('does not render when there are no posts', () => {
    const { container } = render(
      <PostsPager page={0} size={20} totalItems={0} onChange={() => {}} />,
    );
    expect(container).toBeEmptyDOMElement();
  });

  it('requests the next zero-based page', () => {
    const onChange = vi.fn();
    render(<PostsPager page={0} size={2} totalItems={5} onChange={onChange} />);

    expect(screen.getByText('1-2 of 5 posts')).toBeInTheDocument();
    fireEvent.click(screen.getByRole('listitem', { name: '2' }));
    expect(onChange).toHaveBeenCalledWith(1, 2);
  });
});
